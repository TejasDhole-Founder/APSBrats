#!/usr/bin/env python3
"""WebSocket chat load test with a live dashboard (dev/test accounts and a throwaway DB only).

Creates N users, joins them to one school community, opens one STOMP WebSocket per user
(subscribed to /user/queue/community), then posts community chat messages at rising rates.
Every message is pushed to every connected member, so each message = N pushes (worst case).

Measures: connections held, push latency, delivery %, latency of the REST send, latency of
unrelated API calls (probe), and server heap / CPU / DB pool / executor queues from
/actuator/prometheus. Dashboard: http://localhost:8097

Start the API first on a throwaway database (see docs/engineering-wiki/10-development-guide.md):
  RATE_LIMIT_IP_PER_MINUTE=100000 java -jar api.jar --server.port=8090 \
     --spring.datasource.url=jdbc:postgresql://localhost:5432/apsbrat_wsload --spring.data.redis.database=1

  pip install websockets
  python tools/ws_load.py --community-id <id> --school-id <id> --users 1000
"""
import argparse
import asyncio
import json
import os
import random
import re
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from bisect import bisect_left
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import websockets

EDGES = [1.25 ** i for i in range(56)]


class Hist:
    """Log-bucket histogram: cheap to add to from the hot path, gives p50/p95/p99."""
    __slots__ = ("c", "n")

    def __init__(self):
        self.c = [0] * (len(EDGES) + 1)
        self.n = 0

    def add(self, v):
        self.c[bisect_left(EDGES, v)] += 1
        self.n += 1

    def pct(self, p):
        if not self.n:
            return None
        target, acc = p / 100 * self.n, 0
        for i, c in enumerate(self.c):
            acc += c
            if acc >= target:
                return round(EDGES[min(i, len(EDGES) - 1)], 1)


class State:
    def __init__(self):
        self.rows, self.marks, self.stages = [], [], []
        self.status, self.t0 = "starting", time.time()
        self.ws_open = self.ws_failed = self.ws_closed = 0
        self.frames = self.matched = self.stomp_errors = 0
        self.sent = self.ok = self.r429 = self.dropped = 0
        self.send_err, self.conn_err = {}, {}
        self.probe_n = self.probe_err = 0
        self.win_push, self.win_send, self.win_probe = Hist(), Hist(), Hist()
        self.setup_done = self.setup_total = 0
        self.notes = []
        self.final = None

    def mark(self, label):
        self.marks.append({"t": round(time.time() - self.t0, 1), "label": label})


st = State()


def http(method, url, token=None, body=None, timeout=20):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if method == "POST":
        req.add_header("Idempotency-Key", str(uuid.uuid4()))
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = r.read()
            code = r.status
    except urllib.error.HTTPError as e:
        payload, code = e.read(), e.code
    except Exception as e:  # timeout, refused, reset
        return type(e).__name__, {}, (time.perf_counter() - t0) * 1000
    try:
        env = json.loads(payload or b"{}")
    except ValueError:
        env = {}
    return code, env, (time.perf_counter() - t0) * 1000


def make_user(a, i):
    base, run = a.base, a.run
    code, env, _ = http("POST", f"{base}/auth/verify-otp",
                        body={"email": f"{run}{i}@loadtest.example", "code": a.otp})
    if code != 200:
        return None
    token, uid = env["data"]["accessToken"], env["data"]["user"]["id"]
    http("PUT", f"{base}/users/me", token, {"fullName": f"WS Load {i}", "username": f"ws{run}_{i}",
                                            "dob": "1995-06-15", "currentStatus": "ALUMNI"})
    http("POST", f"{base}/users/{uid}/school-history/bulk", token, {"items": [{
        "schoolId": a.school_id, "classFrom": 1, "classTo": 10, "section": "A",
        "batchStart": 2001, "batchEnd": 2011}]})
    http("POST", f"{base}/communities/{a.community_id}/join", token)
    st.setup_done += 1
    return token


def prom(url):
    with urllib.request.urlopen(url, timeout=4) as r:
        text = r.read().decode()
    m = {"heap": 0.0, "heap_max": 0.0, "cpu": None, "threads": None, "hik_active": None,
         "hik_pending": None, "hik_max": None, "exec_q": 0.0, "gc_s": 0.0}
    for line in text.splitlines():
        if line[:1] == "#":
            continue
        try:
            v = float(line.rsplit(" ", 1)[1])
        except (IndexError, ValueError):
            continue
        if line.startswith("jvm_memory_used_bytes{") and 'area="heap"' in line:
            m["heap"] += v
        elif line.startswith("jvm_memory_max_bytes{") and 'area="heap"' in line and v > 0:
            m["heap_max"] += v
        elif line.startswith("process_cpu_usage"):
            m["cpu"] = v
        elif line.startswith("jvm_threads_live_threads"):
            m["threads"] = v
        elif line.startswith("hikaricp_connections_active"):
            m["hik_active"] = v
        elif line.startswith("hikaricp_connections_pending"):
            m["hik_pending"] = v
        elif line.startswith("hikaricp_connections_max"):
            m["hik_max"] = v
        elif line.startswith("executor_queued_tasks"):
            m["exec_q"] += v
        elif line.startswith("jvm_gc_pause_seconds_sum"):
            m["gc_s"] += v
    return m


def frame(command, headers, body=""):
    return f"{command}\n" + "".join(f"{k}:{v}\n" for k, v in headers.items()) + f"\n{body}\x00"


async def sampler(a, pool):
    loop = asyncio.get_running_loop()
    prev = dict(sent=0, ok=0, matched=0, frames=0, gc=None)
    root = a.base.split("/api/")[0]
    while st.status != "stopped":
        t = time.perf_counter()
        await asyncio.sleep(1.0)
        lag = max(0.0, (time.perf_counter() - t - 1.0) * 1000)
        try:
            m = await asyncio.wait_for(loop.run_in_executor(pool, prom, f"{root}/actuator/prometheus"), 5)
        except Exception:
            m = {}
        gc_ms = None
        if m.get("gc_s") is not None and prev["gc"] is not None:
            gc_ms = round(max(0.0, m["gc_s"] - prev["gc"]) * 1000)
        prev["gc"] = m.get("gc_s", prev["gc"])
        wp, ws_, wr = st.win_push, st.win_send, st.win_probe
        st.win_push, st.win_send, st.win_probe = Hist(), Hist(), Hist()
        st.rows.append({
            "t": round(time.time() - st.t0, 1), "ws_open": st.ws_open, "ws_failed": st.ws_failed,
            "send_rate": st.sent - prev["sent"], "ok_rate": st.ok - prev["ok"],
            "push_rate": st.matched - prev["matched"], "frame_rate": st.frames - prev["frames"],
            "push_p50": wp.pct(50), "push_p95": wp.pct(95), "push_p99": wp.pct(99),
            "send_p50": ws_.pct(50), "send_p95": ws_.pct(95),
            "probe_p95": wr.pct(95), "probe_max": wr.pct(100), "probe_err": st.probe_err,
            "lag": round(lag), "heap_mb": round(m["heap"] / 1048576) if m.get("heap") else None,
            "heap_max_mb": round(m["heap_max"] / 1048576) if m.get("heap_max") else None,
            "cpu": round(m["cpu"] * 100) if m.get("cpu") is not None else None,
            "threads": m.get("threads"), "hik_active": m.get("hik_active"),
            "hik_pending": m.get("hik_pending"), "exec_q": m.get("exec_q"), "gc_ms": gc_ms,
        })
        prev.update(sent=st.sent, ok=st.ok, matched=st.matched, frames=st.frames)


class Run:
    def __init__(self, a):
        self.a, self.sent_at, self.seq_stage = a, {}, {}
        self.prefix = f"ws-test {a.run}-"
        self.socks, self.cur_stage = [], -1
        self.stage_hist, self.stage_recv, self.stage_expect = [], [], []


async def client(r, i, token):
    a = r.a
    t0 = time.perf_counter()
    try:
        ws = await websockets.connect(a.ws, ping_interval=30, ping_timeout=90, open_timeout=30, max_size=2 ** 20)
        await ws.send(frame("CONNECT", {"accept-version": "1.2", "host": "localhost",
                                        "Authorization": f"Bearer {token}", "heart-beat": "0,0"}))
        first = await asyncio.wait_for(ws.recv(), 30)
        if not first.startswith("CONNECTED"):
            raise RuntimeError("stomp:" + first[:40].replace("\n", " "))
        await ws.send(frame("SUBSCRIBE", {"id": "s0", "destination": "/user/queue/community"}))
    except Exception as e:
        st.ws_failed += 1
        k = type(e).__name__
        st.conn_err[k] = st.conn_err.get(k, 0) + 1
        return
    st.ws_open += 1
    r.socks.append(ws)
    prefix, plen = r.prefix, len(r.prefix)
    try:
        async for raw in ws:
            st.frames += 1
            if raw[:1] == "E":
                st.stomp_errors += 1
                continue
            k = raw.find(prefix)
            if k < 0:
                continue
            j = k + plen
            e = j
            while raw[e].isdigit():
                e += 1
            seq = int(raw[j:e])
            t0s = r.sent_at.get(seq)
            if t0s is not None:
                ms = (time.perf_counter() - t0s) * 1000
                st.matched += 1
                st.win_push.add(ms)
                s = r.seq_stage[seq]
                r.stage_hist[s].add(ms)
                r.stage_recv[s] += 1
    except websockets.ConnectionClosed:
        pass
    finally:
        st.ws_open -= 1
        st.ws_closed += 1


def do_send(r, token, seq):
    a = r.a
    code, _, ms = http("POST", f"{a.base}/communities/{a.community_id}/chat/messages", token,
                       {"body": f"{r.prefix}{seq}"})
    st.win_send.add(ms)
    st.sent += 1
    if code == 200:
        st.ok += 1
    elif code == 429:
        st.r429 += 1
    else:
        st.send_err[str(code)] = st.send_err.get(str(code), 0) + 1


async def probe(r, token, pool):
    a, loop, n = r.a, asyncio.get_running_loop(), 0
    paths = ["/users/me", "/feed/home?limit=20", f"/communities/{a.community_id}", "/notifications/unread-count"]
    while st.status != "stopped":
        code, _, ms = await loop.run_in_executor(pool, http, "GET", a.base + paths[n % len(paths)], token, None, 15)
        n += 1
        st.probe_n += 1
        st.win_probe.add(ms)
        if code != 200:
            st.probe_err += 1
        await asyncio.sleep(0.5)


async def run_stage(r, idx, rate, seconds, senders, pool):
    loop = asyncio.get_running_loop()
    r.cur_stage = idx
    r.stage_hist.append(Hist())
    r.stage_recv.append(0)
    r.stage_expect.append(0)
    st.status = f"chat stage {idx + 1}: {rate} msg/s for {seconds}s"
    st.mark(f"{rate:g}/s")
    sem = asyncio.Semaphore(200)
    pending, start, n = set(), time.perf_counter(), 0
    total = int(rate * seconds)
    st.stages.append({"rate": rate, "seconds": seconds, "planned": total})
    while n < total:
        due = start + n / rate
        delay = due - time.perf_counter()
        if delay > 0:
            await asyncio.sleep(delay)
        seq = r.a.seq0 + len(r.sent_at)
        if sem.locked():
            st.dropped += 1
            n += 1
            continue
        r.sent_at[seq] = time.perf_counter()
        r.seq_stage[seq] = idx
        r.stage_expect[idx] += st.ws_open
        token = senders[seq % len(senders)]
        await sem.acquire()

        async def job(seq=seq, token=token):
            try:
                await loop.run_in_executor(pool, do_send, r, token, seq)
            finally:
                sem.release()

        t = asyncio.create_task(job())
        pending.add(t)
        t.add_done_callback(pending.discard)
        n += 1
    if pending:
        await asyncio.wait(pending, timeout=30)


def stage_summary(r, i):
    h, s = r.stage_hist[i], st.stages[i]
    exp = r.stage_expect[i]
    s.update(received=r.stage_recv[i], expected=exp,
             delivery_pct=round(100 * r.stage_recv[i] / exp, 1) if exp else None,
             p50=h.pct(50), p95=h.pct(95), p99=h.pct(99))


async def amain(a):
    loop = asyncio.get_running_loop()
    pool = ThreadPoolExecutor(max_workers=96)
    st.status, st.setup_total = f"creating {a.users} test users", a.users
    tokens = [t for t in await asyncio.gather(*[loop.run_in_executor(pool, make_user, a, i) for i in range(a.users)]) if t]
    if len(tokens) < 10:
        st.status = "stopped"
        st.notes.append(f"setup failed: only {len(tokens)} users could be created (check --base, --otp, ids)")
        print(st.notes[-1])
        return
    st.notes.append(f"{len(tokens)} of {a.users} users created and joined")
    r = Run(a)
    r.a.seq0 = 0
    st.t0 = time.time()
    st.rows.clear()
    samp = asyncio.create_task(sampler(a, pool))
    st.status = "baseline (5s)"
    await asyncio.sleep(5)
    base_heap = min([x["heap_mb"] for x in st.rows if x["heap_mb"]] or [0])
    probe_task = asyncio.create_task(probe(r, tokens[0], pool))

    st.status = f"connecting {len(tokens)} WebSockets at {a.connect_rate}/s"
    st.mark("connect")
    clients = []
    for i, tok in enumerate(tokens):
        clients.append(asyncio.create_task(client(r, i, tok)))
        await asyncio.sleep(1 / a.connect_rate)
    t_wait = time.time()
    while st.ws_open + st.ws_failed < len(tokens) and time.time() - t_wait < 60:
        await asyncio.sleep(0.5)
    st.status = f"holding {st.ws_open} idle connections ({a.settle}s)"
    st.mark("hold")
    await asyncio.sleep(a.settle)
    settled = [x["heap_mb"] for x in st.rows[-a.settle:] if x["heap_mb"]]
    heap_per_conn_kb = None
    if base_heap and settled and st.ws_open:
        heap_per_conn_kb = round((min(settled) - base_heap) * 1024 / st.ws_open, 1)

    senders = tokens[1:] or tokens
    for idx, rate in enumerate(a.rates):
        await run_stage(r, idx, rate, a.stage_seconds, senders, pool)
        await asyncio.sleep(3)
    st.status = "draining late pushes (15s)"
    st.mark("drain")
    await asyncio.sleep(15)
    for i in range(len(st.stages)):
        stage_summary(r, i)

    peak = lambda k: max([x[k] for x in st.rows if x.get(k) is not None] or [0])
    st.final = {
        "users": len(tokens), "connected_peak": peak("ws_open"), "connect_failed": st.ws_failed,
        "connect_errors": st.conn_err, "stomp_error_frames": st.stomp_errors,
        "heap_per_conn_kb_approx": heap_per_conn_kb, "heap_peak_mb": peak("heap_mb"),
        "heap_max_mb": peak("heap_max_mb"), "cpu_peak_pct": peak("cpu"),
        "hikari_active_peak": peak("hik_active"), "hikari_pending_peak": peak("hik_pending"),
        "executor_queue_peak": peak("exec_q"), "probe_requests": st.probe_n, "probe_errors": st.probe_err,
        "probe_p95_ms_worst_second": peak("probe_p95"), "client_loop_lag_peak_ms": peak("lag"),
        "send_429": st.r429, "send_other_errors": st.send_err, "client_dropped_sends": st.dropped,
        "closed_during_test": st.ws_closed,
    }
    st.status = "done: closing sockets"
    for ws in list(r.socks):
        await ws.close()
    probe_task.cancel()
    st.status = "done"
    await asyncio.sleep(2)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ws_load_result.json")
    with open(out, "w") as f:
        json.dump({"final": st.final, "stages": st.stages, "notes": st.notes}, f, indent=2)
    print(json.dumps({"final": st.final, "stages": st.stages}, indent=2))
    print("saved", out)
    if a.exit_when_done:
        st.status = "stopped"
        samp.cancel()
    else:
        print("dashboard stays up at http://localhost:%d (Ctrl+C to quit)" % a.port)
        await asyncio.Event().wait()


PAGE = r"""<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>WebSocket load</title><style>
:root{--bg:#f6f7f9;--card:#fff;--fg:#1a1d23;--mut:#6b7280;--line:#e5e7eb;--grid:#eef0f3;--a:#2563eb;--b:#d97706;--c:#16a34a;--d:#dc2626;--e:#7c3aed}
@media(prefers-color-scheme:dark){:root{--bg:#0f1115;--card:#171a21;--fg:#e6e8ec;--mut:#9aa3b2;--line:#2a2f3a;--grid:#222733;--a:#60a5fa;--b:#fbbf24;--c:#4ade80;--d:#f87171;--e:#a78bfa}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.4 system-ui,Segoe UI,sans-serif;padding:16px}
h1{font-size:18px;margin:0 0 4px}#status{color:var(--mut);margin-bottom:12px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-bottom:12px}
.k{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px}.k b{display:block;font-size:22px}.k span{color:var(--mut);font-size:12px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:12px}
@media(max-width:480px){.grid{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:10px 12px}.card h2{font-size:13px;margin:0 0 2px}.card p{margin:0 0 6px;color:var(--mut);font-size:12px}
canvas{width:100%;height:170px;display:block}.lg{font-size:12px;color:var(--mut);margin-top:4px}.lg i{display:inline-block;width:10px;height:3px;margin:0 4px 2px 10px;vertical-align:middle}
table{width:100%;border-collapse:collapse;font-size:13px;margin-top:6px}th,td{padding:5px 8px;text-align:right;border-bottom:1px solid var(--line)}th:first-child,td:first-child{text-align:left}
.warn{color:var(--d)}</style>
<h1>WebSocket chat load test</h1><div id=status>connecting...</div><div class=kpis id=kpis></div><div class=grid id=grid></div>
<div class=card style="margin-top:12px"><h2>Results per stage</h2><p>One chat message is pushed to every connected member, so each message is as many pushes as there are connections.</p><div id=tbl></div></div>
<div class=card style="margin-top:12px"><h2>Final summary</h2><div id=final class=lg></div></div>
<script>
const CH=[
 ["WebSocket connections","open sockets and failed connects",[["ws_open","open","--a"],["ws_failed","failed","--d"]]],
 ["Chat messages per second","accepted by the API",[["ok_rate","messages/s","--a"]]],
 ["Pushes delivered per second","each message goes to every connected member",[["push_rate","pushes/s","--c"],["frame_rate","all frames/s","--mut"]]],
 ["Push latency (ms)","REST send start to socket receipt, per second",[["push_p50","p50","--c"],["push_p95","p95","--b"],["push_p99","p99","--d"]]],
 ["Chat send latency (ms)","the POST itself; includes the push fan-out",[["send_p50","p50","--a"],["send_p95","p95","--b"]]],
 ["Other API calls (ms)","probe of /users/me, feed, community, unread every 0.5s",[["probe_p95","p95","--a"],["probe_max","max","--d"]]],
 ["Server heap (MB)","used vs max",[["heap_mb","used","--a"],["heap_max_mb","max","--mut"]]],
 ["Server CPU % and GC pause ms/s","whole API process",[["cpu","cpu %","--b"],["gc_ms","gc ms/s","--e"]]],
 ["DB pool and executor queue","hikari connections busy, waiting; queued tasks",[["hik_active","pool busy","--a"],["hik_pending","pool waiting","--d"],["exec_q","executor queue","--e"]]],
 ["Test client health","event-loop lag (ms): if high, numbers above are unreliable",[["lag","loop lag","--b"]]],
 ["Server threads","live JVM threads",[["threads","threads","--a"]]]];
const grid=document.getElementById('grid');
CH.forEach((c,i)=>{const d=document.createElement('div');d.className='card';d.innerHTML=`<h2>${c[0]}</h2><p>${c[1]}</p><canvas id=c${i}></canvas><div class=lg>${c[2].map(s=>`<i style="background:var(${s[2]})"></i>${s[1]}`).join('')}</div>`;grid.appendChild(d)});
const css=n=>getComputedStyle(document.documentElement).getPropertyValue(n).trim();
function draw(cv,rows,marks,series){const dpr=devicePixelRatio||1,W=cv.clientWidth,H=cv.clientHeight;cv.width=W*dpr;cv.height=H*dpr;const g=cv.getContext('2d');g.scale(dpr,dpr);g.clearRect(0,0,W,H);
 const L=44,R=8,T=6,B=18,t0=rows.length?rows[0].t:0,t1=rows.length?rows[rows.length-1].t:1;let mx=0;
 series.forEach(s=>rows.forEach(r=>{if(r[s[0]]!=null&&r[s[0]]>mx)mx=r[s[0]]}));mx=mx||1;const nice=Math.pow(10,Math.floor(Math.log10(mx)));mx=Math.ceil(mx/nice*1.1*2)/2*nice||1;
 const X=t=>L+(t-t0)/Math.max(1,t1-t0)*(W-L-R),Y=v=>T+(1-v/mx)*(H-T-B);g.font='11px system-ui';g.fillStyle=css('--mut');g.strokeStyle=css('--grid');g.lineWidth=1;
 for(let k=0;k<=4;k++){const v=mx*k/4,y=Y(v);g.beginPath();g.moveTo(L,y);g.lineTo(W-R,y);g.stroke();g.fillText(v>=100?Math.round(v):v.toFixed(1),4,y+3)}
 marks.forEach(m=>{const x=X(m.t);if(x<L||x>W-R)return;g.strokeStyle=css('--line');g.beginPath();g.moveTo(x,T);g.lineTo(x,H-B);g.stroke();g.fillStyle=css('--mut');g.fillText(m.label,x+2,H-5)});
 series.forEach(s=>{g.strokeStyle=css(s[2]);g.lineWidth=1.8;g.beginPath();let on=false;rows.forEach(r=>{const v=r[s[0]];if(v==null){on=false;return}const x=X(r.t),y=Y(v);if(!on){g.moveTo(x,y);on=true}else g.lineTo(x,y)});g.stroke()})}
const f=(v,u='')=>v==null?'-':v+u;
async function tick(){try{const j=await (await fetch('/stats')).json();const rows=j.rows,last=rows[rows.length-1]||{};
 document.getElementById('status').textContent=j.status+(j.notes.length?'  |  '+j.notes.join(' | '):'');
 const dl=j.stages.reduce((a,s)=>a+(s.received||0),0);
 document.getElementById('kpis').innerHTML=[['Connected',f(last.ws_open)],['Connect failed',f(last.ws_failed)],['Messages ok/s',f(last.ok_rate)],['Pushes/s',f(last.push_rate)],['Push p95 ms',f(last.push_p95)],['Other API p95 ms',f(last.probe_p95)],['Heap MB',f(last.heap_mb)+' / '+f(last.heap_max_mb)],['CPU %',f(last.cpu)],['Pool busy / wait',f(last.hik_active)+' / '+f(last.hik_pending)],['Users setup',j.setup_done+'/'+j.setup_total]].map(k=>`<div class=k><b>${k[1]}</b><span>${k[0]}</span></div>`).join('');
 CH.forEach((c,i)=>draw(document.getElementById('c'+i),rows,j.marks,c[2]));
 document.getElementById('tbl').innerHTML=j.stages.length?`<table><tr><th>Rate msg/s</th><th>Planned</th><th>Pushes expected</th><th>Received</th><th>Delivered %</th><th>p50 ms</th><th>p95 ms</th><th>p99 ms</th></tr>`+j.stages.map(s=>`<tr><td>${s.rate}</td><td>${s.planned}</td><td>${f(s.expected)}</td><td>${f(s.received)}</td><td class="${s.delivery_pct!=null&&s.delivery_pct<99?'warn':''}">${f(s.delivery_pct)}</td><td>${f(s.p50)}</td><td>${f(s.p95)}</td><td>${f(s.p99)}</td></tr>`).join('')+`</table>`:'<div class=lg>No stage finished yet.</div>';
 if(j.final)document.getElementById('final').innerHTML=Object.entries(j.final).map(([k,v])=>`<div><b>${k}</b>: ${typeof v==='object'?JSON.stringify(v):v}</div>`).join('')}catch(e){}}
tick();setInterval(tick,1000);
</script>"""


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path.startswith("/stats"):
            body = json.dumps({"rows": st.rows[-900:], "marks": st.marks, "stages": st.stages, "status": st.status,
                               "notes": st.notes, "final": st.final, "setup_done": st.setup_done,
                               "setup_total": st.setup_total}).encode()
            ctype = "application/json"
        else:
            body, ctype = PAGE.encode(), "text/html; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--base", default="http://localhost:8090/api/v1")
    p.add_argument("--ws", default="ws://localhost:8090/ws")
    p.add_argument("--community-id", required=True)
    p.add_argument("--school-id", required=True)
    p.add_argument("--users", type=int, default=1000)
    p.add_argument("--otp", default=os.environ.get("OTP_CODE", "000000"), help="dev master OTP (dev profile only)")
    p.add_argument("--connect-rate", type=float, default=100, help="new sockets per second")
    p.add_argument("--settle", type=int, default=15, help="seconds to hold idle sockets before chatting")
    p.add_argument("--rates", default="1,2,5,10", help="messages per second per stage, comma separated")
    p.add_argument("--stage-seconds", type=int, default=20)
    p.add_argument("--port", type=int, default=8097)
    p.add_argument("--exit-when-done", action="store_true")
    a = p.parse_args()
    a.rates = [float(x) for x in a.rates.split(",") if x]
    a.run = uuid.uuid4().hex[:4]
    srv = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    print(f"dashboard: http://localhost:{a.port}")
    try:
        asyncio.run(amain(a))
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
