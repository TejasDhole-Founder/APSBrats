import json
import subprocess
import threading
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


def psql(sql):
    return subprocess.run(["docker", "exec", "apsbrats-db-1", "psql", "-U", "aps_user", "-d", "apsbrat_db", "-Atc", sql],
                          capture_output=True, text=True).stdout.strip()


arjun, arjun_id = login("arjun.singh@example.com")
sara, sara_id = login("seed.sarasharma25@example.com")
a1, a1_id = login("seed.aadhyabhatt99@example.com")
a2, a2_id = login("seed.aadhyaiyer19@example.com")
communities, posts = [], []

try:
    s, b = call("POST", "/communities", arjun, {"name": "E2E Open Group", "visibility": "OPEN"})
    open_id = b["data"]["id"]; communities.append(open_id)
    s, b = call("POST", "/communities", arjun, {"name": "E2E Private Group", "visibility": "PRIVATE"})
    priv_id = b["data"]["id"]; communities.append(priv_id)
    for t in (sara, a1, a2):
        call("POST", f"/communities/{open_id}/join", t)

    # ── Chapter 6: posts ──
    s, b = call("POST", f"/communities/{open_id}/posts", arjun, {"body": "  First post!  "})
    check("member posts; body is trimmed", s == 200 and b["data"]["body"] == "First post!" and b["data"]["author"]["id"] == arjun_id, b)
    p1 = b["data"]["id"]; posts.append(p1)
    s, b = call("POST", f"/communities/{open_id}/posts", arjun, {"body": "   "})
    check("blank post -> 400", s == 400, b)
    s, b = call("POST", f"/communities/{priv_id}/posts", sara, {"body": "hi"})
    check("non-member can't post -> 403", s == 403, b)
    s, b = call("GET", f"/communities/{priv_id}/posts", sara)
    check("non-member can't read a private community -> 403", s == 403, b)
    pune = next(c for c in call("GET", "/communities/mine", arjun)[1]["data"]["suggested"] if c["name"] == "APS Pune")
    s, b = call("GET", f"/communities/{pune['id']}/posts", sara)
    check("not that school's student -> 404", s == 404, b)

    for i in range(2, 5):
        s, b = call("POST", f"/communities/{open_id}/posts", sara, {"body": f"Post {i}"})
        posts.append(b["data"]["id"])
    s, b = call("GET", f"/communities/{open_id}/posts?limit=2", a1)
    page1 = b["data"]
    check("newest first, page of 2 with a next page", [p["body"] for p in page1["items"]] == ["Post 4", "Post 3"] and page1["hasMore"], page1)
    s, b = call("GET", f"/communities/{open_id}/posts?limit=2&cursor={page1['nextCursor']}", a1)
    check("page 2 continues where page 1 stopped", [p["body"] for p in b["data"]["items"]] == ["Post 2", "First post!"] and not b["data"]["hasMore"], b)
    check("canDelete: only on my own posts for a plain member", all(not p["canDelete"] for p in page1["items"]), page1)
    s, b = call("GET", f"/communities/{open_id}/posts?limit=2", arjun)
    check("owner can delete anyone's post in their community", all(p["canDelete"] for p in b["data"]["items"]), b)

    s, b = call("DELETE", f"/posts/{posts[1]}", a1)
    check("another member can't delete Sara's post -> 403", s == 403, b)
    s, b = call("DELETE", f"/posts/{posts[1]}", sara)
    check("author deletes her post", s == 200, b)
    s, b = call("GET", f"/posts/{posts[1]}", a1)
    check("deleted post is gone (404)", s == 404, b)
    check("...and kept in the database as REMOVED", psql(f"select status from posts where id='{posts[1]}'") == "REMOVED")

    # ── Chapter 7: likes ──
    s, b = call("PUT", f"/posts/{p1}/like", sara)
    check("like -> count 1, likedByMe", b["data"]["likeCount"] == 1 and b["data"]["likedByMe"], b)
    s, b = call("PUT", f"/posts/{p1}/like", sara)
    check("liking twice keeps it at 1", b["data"]["likeCount"] == 1, b)
    results = []
    ts = [threading.Thread(target=lambda t=t: results.append(call("PUT", f"/posts/{p1}/like", t)[0])) for t in (a1, a2)]
    [t.start() for t in ts]; [t.join() for t in ts]
    s, b = call("GET", f"/posts/{p1}", arjun)
    check("two people liking at the same moment -> 3", b["data"]["likeCount"] == 3 and results == [200, 200], (b, results))
    s, b = call("DELETE", f"/posts/{p1}/like", sara)
    check("unlike -> 2", b["data"]["likeCount"] == 2 and not b["data"]["likedByMe"], b)
    s, b = call("DELETE", f"/posts/{p1}/like", sara)
    check("unliking twice keeps it at 2", b["data"]["likeCount"] == 2, b)

    # ── Chapter 7: comments ──
    before = int(psql(f"select count(*) from notifications n join users u on u.id=n.user_id where u.email='arjun.singh@example.com'"))
    s, b = call("POST", f"/posts/{p1}/comments", sara, {"body": "Nice one"})
    check("comment added", s == 200 and b["data"]["body"] == "Nice one", b)
    c1 = b["data"]["id"]
    call("POST", f"/posts/{p1}/comments", a1, {"body": "Agreed"})
    s, b = call("GET", f"/posts/{p1}/comments", a2)
    check("comments oldest first", [c["body"] for c in b["data"]["items"]] == ["Nice one", "Agreed"], b)
    s, b = call("GET", f"/posts/{p1}", a2)
    check("comment count 2", b["data"]["commentCount"] == 2, b)
    after = int(psql(f"select count(*) from notifications n join users u on u.id=n.user_id where u.email='arjun.singh@example.com'"))
    check("post author got a notification per comment", after - before == 2, (before, after))
    s, b = call("DELETE", f"/comments/{c1}", a2)
    check("a stranger can't delete a comment -> 403", s == 403, b)
    s, b = call("DELETE", f"/comments/{c1}", arjun)
    check("community owner deletes Sara's comment", s == 200, b)
    s, b = call("GET", f"/posts/{p1}", a2)
    check("comment count back to 1", b["data"]["commentCount"] == 1, b)

    # ── Chapter 8: reports + blocks ──
    target = posts[2]
    for i in range(3):
        s, b = call("POST", "/reports", sara, {"targetType": "POST", "targetId": target, "reason": "SPAM"})
    s, b = call("GET", f"/posts/{target}", a1)
    check("one person reporting 3 times does NOT hide it", s == 200, b)
    call("POST", "/reports", a1, {"targetType": "POST", "targetId": target, "reason": "SPAM"})
    s, b = call("GET", f"/posts/{target}", a2)
    check("2 different reporters: still visible", s == 200, b)
    call("POST", "/reports", a2, {"targetType": "POST", "targetId": target, "reason": "SPAM"})
    s, b = call("GET", f"/posts/{target}", arjun)
    check("3rd different reporter hides it for everyone", s == 404, b)
    check("...as HIDDEN (kept for review)", psql(f"select status from posts where id='{target}'") == "HIDDEN")
    s, b = call("POST", "/reports", sara, {"targetType": "POST", "targetId": "00000000-0000-0000-0000-000000000001", "reason": "SPAM"})
    check("reporting a post that doesn't exist -> 404", s == 404, b)

    s, b = call("POST", f"/users/{arjun_id}/block", sara)
    check("Sara blocks Arjun", s == 200, b)
    s, b = call("GET", f"/communities/{open_id}/posts", sara)
    check("Sara no longer sees Arjun's posts", all(p["author"]["id"] != arjun_id for p in b["data"]["items"]), b)
    s, b = call("GET", f"/posts/{p1}", sara)
    check("...nor can she open one", s == 404, b)
    call("DELETE", f"/users/{arjun_id}/block", sara)
    s, b = call("GET", f"/posts/{p1}", sara)
    check("after unblocking she sees it again", s == 200, b)

    # ── Chapter 9: Home feed ──
    s, b = call("GET", "/feed/home", a1)
    bodies = [p["body"] for p in b["data"]["items"]]
    check("Home shows newest posts from my communities", s == 200 and bodies[:1] == ["Post 4"] and "First post!" in bodies, b)
    s, b = call("GET", "/feed/home", sara)
    check("Home includes the community name on each post", all(p["communityName"] for p in b["data"]["items"]), b)
    call("DELETE", f"/communities/{open_id}/members/me", a2)
    s, b = call("GET", "/feed/home", a2)
    check("after leaving, Home has none of its posts", not any(p["communityId"] == open_id for p in b["data"]["items"]), b)
finally:
    ids = ",".join(f"'{p}'" for p in posts)
    for cid in communities:
        call("DELETE", f"/communities/{cid}", arjun)
    if posts:
        psql(f"delete from reports where target_id in ({ids})")
        psql(f"delete from notifications where ref_type='POST' and ref_id in ({ids})")
    subprocess.run(["docker", "exec", "apsbrats-redis-1", "sh", "-c",
                    "redis-cli --scan --pattern 'ratelimit:*' | xargs -r redis-cli del"], capture_output=True)
    call("DELETE", f"/users/{arjun_id}/block", sara)
    print("cleaned up")
print("ALL CHECKS PASSED")
