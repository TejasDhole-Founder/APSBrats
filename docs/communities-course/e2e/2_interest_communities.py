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


def check(label, cond, extra=""):
    print(("PASS " if cond else "FAIL ") + label + ("" if cond else f"  -> {extra}"))
    if not cond:
        raise SystemExit(1)


arjun, arjun_id = login("arjun.singh@example.com")
sara, sara_id = login("seed.sarasharma25@example.com")
created = []
try:
    s, b = call("POST", "/communities", arjun, {"name": "Software Developers", "description": "Code and careers", "visibility": "OPEN"})
    check("Arjun creates an open community", s == 200 and b["data"]["myRole"] == "OWNER" and b["data"]["memberCount"] == 1, b)
    devs = b["data"]["id"]; created.append(devs)

    s, b = call("POST", "/communities", sara, {"name": "software  developers!", "visibility": "OPEN"})
    check("same name with different case/punctuation -> 409", s == 409, b)

    s, b = call("POST", "/communities", arjun, {"name": "NDA Aspirants", "visibility": "PRIVATE"})
    check("Arjun creates a private community", s == 200 and b["data"]["visibility"] == "PRIVATE", b)
    nda = b["data"]["id"]; created.append(nda)

    s, b = call("POST", "/communities", arjun, {"name": "x", "visibility": "OPEN"})
    check("too-short name -> 400", s == 400, b)

    s, b = call("GET", "/communities/discover?q=soft", sara)
    names = [c["name"] for c in b["data"]]
    check("Sara finds it in Discover by part of the name", s == 200 and "Software Developers" in names, b)
    s, b = call("GET", "/communities/discover", sara)
    check("Discover lists interest communities only (no schools)", all(c["type"] == "INTEREST" for c in b["data"]), b)

    s, b = call("POST", f"/communities/{devs}/join", sara)
    check("Sara joins the open one instantly", s == 200 and b["data"]["myRole"] == "MEMBER" and b["data"]["memberCount"] == 2, b)

    s, b = call("POST", f"/communities/{nda}/join", sara)
    check("Sara's join on the private one becomes a request", s == 200 and b["data"]["myRole"] is None and b["data"]["requested"] is True, b)
    s, b = call("GET", "/communities/discover?q=nda", sara)
    check("Discover shows her request as pending", b["data"][0]["requested"] is True, b)

    s, b = call("GET", f"/communities/{nda}/requests", sara)
    check("a non-owner can't see requests -> 403", s == 403, b)
    s, b = call("GET", f"/communities/{nda}/requests", arjun)
    check("owner sees Sara's request with her profile", s == 200 and len(b["data"]) == 1 and b["data"][0]["person"]["id"] == sara_id, b)

    s, b = call("POST", f"/communities/{nda}/requests/{sara_id}/approve", arjun)
    check("owner approves", s == 200, b)
    s, b = call("GET", f"/communities/{nda}", sara)
    check("Sara is now a member, count 2, no pending request", b["data"]["myRole"] == "MEMBER" and b["data"]["memberCount"] == 2 and b["data"]["requested"] is False, b)

    s, b = call("DELETE", f"/communities/{nda}/members/{sara_id}", arjun)
    check("owner removes Sara", s == 200, b)
    call("POST", f"/communities/{nda}/join", sara)
    s, b = call("POST", f"/communities/{nda}/requests/{sara_id}/reject", arjun)
    check("owner rejects a new request", s == 200, b)
    s, b = call("GET", f"/communities/{nda}", sara)
    check("after reject: not a member, not requested, count 1", b["data"]["myRole"] is None and not b["data"]["requested"] and b["data"]["memberCount"] == 1, b)

    s, b = call("DELETE", f"/communities/{nda}/members/me", arjun)
    check("owner can't leave -> 400", s == 400, b)
    s, b = call("DELETE", f"/communities/{devs}", sara)
    check("a member can't delete the community -> 403", s == 403, b)

    for i in range(3):
        s, b = call("POST", "/communities", arjun, {"name": f"Test Group {i}", "visibility": "OPEN"})
        created.append(b["data"]["id"])
    s, b = call("POST", "/communities", arjun, {"name": "Test Group 9", "visibility": "OPEN"})
    check("6th community -> 400 (max 5 each)", s == 400 and "5" in b.get("error", ""), b)
finally:
    for cid in created:
        call("DELETE", f"/communities/{cid}", arjun)
    print("cleaned up", len(created), "test communities")

s, b = call("GET", "/communities/discover", sara)
check("after owner deletes, they're gone from Discover", not any(c["id"] in created for c in b["data"]), b)
print("ALL CHECKS PASSED")
