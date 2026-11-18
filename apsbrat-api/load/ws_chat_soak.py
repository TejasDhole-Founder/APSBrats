#!/usr/bin/env python3
"""WebSocket chat soak test (dev/test accounts only).

Holds ONE STOMP-over-WebSocket connection open as user B, while user A sends
direct messages over REST. Every message is tagged; when B's socket receives
the push, the script records the latency from the moment A's send started.

Requires: pip install websockets

Example:
  set OTP_CODE=<dev master OTP>
  python load/ws_chat_soak.py --base http://localhost:8090 --ws ws://localhost:8090/ws \
      --email-a soak-a@test.local --email-b soak-b@test.local --messages 300 --interval 1
"""
import argparse
import asyncio
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

import websockets

MARKER = re.compile(r"ws-test ([0-9a-f]{8})-(\d+)")


def http(method, url, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if method == "POST":
        req.add_header("Idempotency-Key", str(uuid.uuid4()))
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read() or b"{}")
        except ValueError:
            return e.code, {}


def login(base, email, otp):
    st, _ = http("POST", f"{base}/api/v1/auth/request-otp", body={"email": email})
    if st != 200:
        sys.exit(f"request-otp failed for {email}: HTTP {st}")
    st, env = http("POST", f"{base}/api/v1/auth/verify-otp", body={"email": email, "code": otp})
    if st != 200:
        sys.exit(f"verify-otp failed for {email}: HTTP {st}")
    data = env["data"]
    return data["accessToken"], data["user"]["id"]


def frame(command, headers, body=""):
    lines = "".join(f"{k}:{v}\n" for k, v in headers.items())
    return f"{command}\n{lines}\n{body}\x00"


def parse(raw):
    head, _, body = raw.strip("\n").partition("\n\n")
    lines = head.split("\n")
    headers = dict(line.split(":", 1) for line in lines[1:] if ":" in line)
    return lines[0], headers, body.split("\x00")[0]


def pct(values, p):
    if not values:
        return float("nan")
    xs = sorted(values)
    return xs[min(len(xs) - 1, round(p / 100 * (len(xs) - 1)))]


async def run(args):
    otp = args.otp or os.environ.get("OTP_CODE")
    if not otp:
        sys.exit("Give the dev master OTP with --otp or the OTP_CODE environment variable.")

    tok_a, _ = login(args.base, args.email_a, otp)
    tok_b, id_b = login(args.base, args.email_b, otp)
    st, env = http("POST", f"{args.base}/api/v1/conversations/with/{id_b}", tok_a)
    if st != 200:
        sys.exit(f"open conversation failed: HTTP {st}")
    conv = env["data"]["id"]

    run_id = uuid.uuid4().hex[:8]
    sent_at, latencies = {}, []
    send_status = {}
    ws_errors, ws_closed = [], []

    async with websockets.connect(args.ws, ping_interval=20, ping_timeout=20) as ws:
        await ws.send(frame("CONNECT", {
            "accept-version": "1.2", "host": "localhost",
            "Authorization": f"Bearer {tok_b}", "heart-beat": "0,0",
        }))
        cmd, _, body = parse(await asyncio.wait_for(ws.recv(), 10))
        if cmd != "CONNECTED":
            sys.exit(f"STOMP connect failed: {cmd} {body}")
        await ws.send(frame("SUBSCRIBE", {"id": "sub-0", "destination": "/user/queue/messages"}))
        print("connected as B, subscribed to /user/queue/messages")

        async def reader():
            try:
                async for raw in ws:
                    cmd, headers, body = parse(raw)
                    if cmd == "ERROR":
                        ws_errors.append(headers.get("message", body))
                    elif cmd == "MESSAGE":
                        m = MARKER.search(body)
                        if m and m.group(1) == run_id:
                            t0 = sent_at.pop(int(m.group(2)), None)
                            if t0 is not None:
                                latencies.append(time.perf_counter() - t0)
            except websockets.ConnectionClosed as e:
                ws_closed.append(str(e))

        reader_task = asyncio.create_task(reader())
        started = time.perf_counter()

        for i in range(args.messages):
            if reader_task.done():
                print(f"socket dropped at message {i}; stopping sends")
                break
            sent_at[i] = time.perf_counter()
            st, _ = await asyncio.to_thread(
                http, "POST", f"{args.base}/api/v1/conversations/{conv}/messages",
                tok_a, {"body": f"ws-test {run_id}-{i}"})
            send_status[st] = send_status.get(st, 0) + 1
            if st != 200:
                sent_at.pop(i, None)
            await asyncio.sleep(args.interval)

        await asyncio.sleep(args.drain)
        reader_task.cancel()
        elapsed = time.perf_counter() - started

    ok = send_status.get(200, 0)
    print("\n=== result ===")
    print(f"elapsed            {elapsed:.1f}s")
    print(f"REST sends         {sum(send_status.values())} (by status: {send_status})")
    print(f"pushes received    {len(latencies)} of {ok} successful sends")
    print(f"lost pushes        {ok - len(latencies)}")
    if latencies:
        ms = [x * 1000 for x in latencies]
        print(f"push latency ms    p50={pct(ms, 50):.0f}  p95={pct(ms, 95):.0f}  "
              f"p99={pct(ms, 99):.0f}  max={max(ms):.0f}")
    print(f"STOMP ERROR frames {len(ws_errors)} {ws_errors[:3]}")
    print(f"socket closed      {len(ws_closed)} {ws_closed[:1]}")
    if send_status.get(429):
        print("note: 429 = per-user request budget (300/min) hit; slow --interval down")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--base", default="http://localhost:8090")
    p.add_argument("--ws", default="ws://localhost:8090/ws")
    p.add_argument("--email-a", default="soak-a@test.local", help="sender (dev/test account)")
    p.add_argument("--email-b", default="soak-b@test.local", help="receiver holding the socket")
    p.add_argument("--otp", help="dev master OTP (or set OTP_CODE)")
    p.add_argument("--messages", type=int, default=200)
    p.add_argument("--interval", type=float, default=1.0, help="seconds between sends (min ~0.25 for the 300/min budget)")
    p.add_argument("--drain", type=float, default=10.0, help="seconds to wait for late pushes")
    asyncio.run(run(p.parse_args()))


if __name__ == "__main__":
    main()
