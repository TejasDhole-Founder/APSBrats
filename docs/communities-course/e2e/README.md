# Communities end-to-end checks

Each script logs in as seeded dev users (master OTP `000000`), exercises one area
against a running backend, prints PASS/FAIL per rule, and deletes what it created.

```bash
python docs/communities-course/e2e/1_school_communities.py
python docs/communities-course/e2e/2_interest_communities.py
python docs/communities-course/e2e/3_posts_likes_comments_reports_home.py
```

Default backend: `http://localhost:8080/api/v1`. Point elsewhere with `API=http://localhost:8099/api/v1`.
Script 3 also uses `docker exec` on `apsbrats-db-1` / `apsbrats-redis-1` to verify and clean up.
Needs the dev seed users (arjun.singh, seed.sarasharma25, seed.aadhyabhatt99, seed.aadhyaiyer19).
