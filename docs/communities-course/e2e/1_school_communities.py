import json
import urllib.request

import os
BASE = os.environ.get("API", "http://localhost:8080/api/v1")


def call(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read() or b"{}")


def login(email):
    s, b = call("POST", "/auth/verify-otp", body={"email": email, "code": "000000"})
    assert s == 200, (s, b)
    return b["data"]["accessToken"], b["data"]["user"]["id"]


def check(label, cond):
    print(("PASS " if cond else "FAIL ") + label)
    if not cond:
        raise SystemExit(1)


arjun, arjun_id = login("arjun.singh@example.com")
sara, _ = login("seed.sarasharma25@example.com")

s, b = call("GET", "/communities/mine", arjun)
suggested = {c["name"]: c for c in b["data"]["suggested"]}
check("Arjun sees his 3 schools as suggestions", s == 200 and set(suggested) >= {"APS Pune", "APS Patiala", "APS Delhi Cantt"} and not b["data"]["joined"])
pune = suggested["APS Pune"]
check("suggestion is OPEN, 0 members, not joined", pune["visibility"] == "OPEN" and pune["memberCount"] == 0 and pune["myRole"] is None)

s, b = call("POST", f"/communities/{pune['id']}/join", arjun)
check("Arjun joins APS Pune -> MEMBER, count 1", s == 200 and b["data"]["myRole"] == "MEMBER" and b["data"]["memberCount"] == 1)
s, b = call("POST", f"/communities/{pune['id']}/join", arjun)
check("joining twice changes nothing (count still 1)", s == 200 and b["data"]["memberCount"] == 1)

s, b = call("GET", "/communities/mine", arjun)
check("APS Pune moved from suggested to joined", [c["name"] for c in b["data"]["joined"]] == ["APS Pune"] and "APS Pune" not in [c["name"] for c in b["data"]["suggested"]])

s, b = call("GET", f"/communities/{pune['id']}", sara)
check("Sara (not from APS Pune) gets 404 viewing it", s == 404)
s, b = call("POST", f"/communities/{pune['id']}/join", sara)
check("Sara gets 404 joining it", s == 404)

s, b = call("DELETE", f"/communities/{pune['id']}/members/me", arjun)
check("Arjun leaves", s == 200)
s, b = call("GET", f"/communities/{pune['id']}", arjun)
check("after leaving: not a member, count 0", b["data"]["myRole"] is None and b["data"]["memberCount"] == 0)
s, b = call("DELETE", f"/communities/{pune['id']}/members/me", arjun)
check("leaving again -> 404", s == 404)

# Auto-remove: join Pune again, drop Pune from school history, expect removal.
call("POST", f"/communities/{pune['id']}/join", arjun)
s, b = call("GET", f"/users/{arjun_id}/school-history", arjun)
original = b["data"]
keys = ["schoolId", "classFrom", "classTo", "section", "batchStart", "batchEnd", "stream"]
def item(h):
    d = {k: h.get(k) for k in keys}
    d["isPrimary"] = h.get("isPrimary", False)
    return {k: v for k, v in d.items() if v is not None}
without_pune = [item(h) for h in original if h["schoolName"] != "APS Pune"]
try:
    s, b = call("POST", f"/users/{arjun_id}/school-history/bulk", arjun, {"items": without_pune})
    check("saved history without APS Pune", s == 200)
    s, b = call("GET", "/communities/mine", arjun)
    check("auto-removed from APS Pune", "APS Pune" not in [c["name"] for c in b["data"]["joined"] + b["data"]["suggested"]])
    s, b = call("GET", f"/communities/{pune['id']}", arjun)
    check("APS Pune is now 404 for Arjun", s == 404)
finally:
    s, b = call("POST", f"/users/{arjun_id}/school-history/bulk", arjun, {"items": [item(h) for h in original]})
    print("restored Arjun's school history:", s)
s, b = call("GET", f"/communities/{pune['id']}", arjun)
check("history restored -> APS Pune visible again, count 0", s == 200 and b["data"]["memberCount"] == 0 and b["data"]["myRole"] is None)
print("ALL CHECKS PASSED")
