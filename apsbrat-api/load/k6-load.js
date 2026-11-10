// Load tests for the APSBrats API (QA audit section 3).
//
// Run against a throwaway database, never your dev data: start the API with
//   --spring.datasource.url=jdbc:postgresql://localhost:5432/apsbrat_loadtest --spring.data.redis.database=1
// and RATE_LIMIT_IP_PER_MINUTE=100000, because every test login comes from one IP.
// Needs the dev profile: test users sign in with the dev master OTP (000000).
//
//   k6 run -e SCENARIO=baseline -e COMMUNITY_ID=... -e SCHOOL_ID=... load/k6-load.js
//   k6 run -e SCENARIO=normal -e DURATION=10m -e COMMUNITY_ID=... -e SCHOOL_ID=... load/k6-load.js
//   SCENARIO: baseline | normal | stress | spike | login | chat
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter } from 'k6/metrics';

const BASE = __ENV.BASE_URL || 'http://localhost:8081/api/v1';
const SCENARIO = __ENV.SCENARIO || 'baseline';
const RUN = __ENV.RUN || 'lt';
// A seeded school community and its school: the test users join it.
//   select id, school_id from communities where type = 'SCHOOL' limit 1;
const COMMUNITY_ID = __ENV.COMMUNITY_ID;
const SCHOOL_ID = __ENV.SCHOOL_ID;
if (!COMMUNITY_ID || !SCHOOL_ID) throw new Error('Set -e COMMUNITY_ID=... -e SCHOOL_ID=... (see the query above)');

const scenarios = {
  baseline: { executor: 'constant-vus', vus: 10, duration: __ENV.DURATION || '1m', exec: 'browse' },
  normal: { executor: 'constant-vus', vus: 100, duration: __ENV.DURATION || '2m', exec: 'browse' },
  stress: {
    executor: 'ramping-vus', exec: 'browse',
    stages: [{ duration: '1m', target: 250 }, { duration: '1m', target: 500 }, { duration: '30s', target: 0 }],
  },
  spike: {
    executor: 'ramping-vus', exec: 'browse',
    stages: [{ duration: '30s', target: 1000 }, { duration: '1m', target: 1000 }, { duration: '15s', target: 0 }],
  },
  login: { executor: 'per-vu-iterations', vus: 200, iterations: 1, exec: 'login' },
  chat: { executor: 'constant-vus', vus: 50, duration: __ENV.DURATION || '2m', exec: 'chat' },
};
const usersNeeded = { baseline: 10, normal: 100, stress: 500, spike: 1000, login: 1, chat: 50 };

export const options = {
  scenarios: { [SCENARIO]: scenarios[SCENARIO] },
  setupTimeout: '10m',
  thresholds: {
    'http_req_failed{phase:test}': ['rate<0.01'],
    'http_req_duration{phase:test}': ['p(95)<1000'],
  },
};

// 429s from the app's own per-action limits are expected and counted on their own.
const rateLimited = new Counter('rate_limited_429');
const json = (token) => ({
  headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  tags: { phase: 'test' },
  responseCallback: http.expectedStatuses({ min: 200, max: 299 }, 429),
});
const setupParams = (token) => ({ ...json(token), tags: { phase: 'setup' } });

function signIn(email, params) {
  const res = http.post(`${BASE}/auth/verify-otp`, JSON.stringify({ email, code: '000000' }), params);
  return res.status === 200 ? res.json('data.accessToken') : null;
}

export function setup() {
  const n = Number(__ENV.USERS || usersNeeded[SCENARIO]);
  const tokens = [];
  for (let start = 0; start < n; start += 50) {
    const ids = [...Array(Math.min(50, n - start)).keys()].map((k) => start + k);
    const logins = http.batch(ids.map((i) => ['POST', `${BASE}/auth/verify-otp`,
      JSON.stringify({ email: `${RUN}${i}@loadtest.example`, code: '000000' }), setupParams()]));
    const batchTokens = logins.map((r) => r.json('data.accessToken'));
    const profiles = http.batch(ids.map((i, k) => ['PUT', `${BASE}/users/me`, JSON.stringify({
      fullName: `Load Tester ${i}`, username: `${RUN}_${i}`, dob: '1995-06-15', currentStatus: 'ALUMNI',
    }), setupParams(batchTokens[k])]));
    // A school community is only visible to people who list that school.
    http.batch(profiles.map((r, k) => ['POST', `${BASE}/users/${r.json('data.id')}/school-history/bulk`,
      JSON.stringify({ items: [{
        // Class 10, not 12: classes 11-12 also need a stream.
        schoolId: SCHOOL_ID, classFrom: 1, classTo: 10, section: 'A', batchStart: 2001, batchEnd: 2011,
      }] }), setupParams(batchTokens[k])]));
    tokens.push(...batchTokens);
  }

  for (let start = 0; start < tokens.length; start += 50) {
    http.batch(tokens.slice(start, start + 50).map((t) =>
      ['POST', `${BASE}/communities/${COMMUNITY_ID}/join`, null, setupParams(t)]));
  }
  const check0 = http.get(`${BASE}/communities/${COMMUNITY_ID}`, setupParams(tokens[0]));
  if (check0.status !== 200) throw new Error(`Test users can't open the community: ${check0.body}`);
  return { tokens, communityId: COMMUNITY_ID };
}

function tokenFor(data) {
  return data.tokens[(__VU - 1) % data.tokens.length];
}

function ok(res, name) {
  if (res.status === 429) rateLimited.add(1);
  check(res, { [`${name} 2xx/429`]: (r) => (r.status >= 200 && r.status < 300) || r.status === 429 });
}

// One "session": what the app loads on Home, plus opening the community.
export function browse(data) {
  const p = json(tokenFor(data));
  const c = data.communityId;
  const responses = http.batch([
    ['GET', `${BASE}/feed/home?limit=20`, null, p],
    ['GET', `${BASE}/users/me`, null, p],
    ['GET', `${BASE}/notifications/unread-count`, null, p],
  ]);
  responses.forEach((r, i) => ok(r, ['feed', 'me', 'unread'][i]));
  sleep(1 + Math.random() * 2);
  ok(http.get(`${BASE}/communities/${c}`, p), 'community');
  ok(http.get(`${BASE}/communities/${c}/posts?sort=latest`, p), 'posts');
  ok(http.get(`${BASE}/communities/${c}/members?page=0`, p), 'members');
  if (Math.random() < 0.1) {
    ok(http.post(`${BASE}/communities/${c}/posts`,
      JSON.stringify({ body: `load test post ${__VU}-${__ITER}` }), p), 'create post');
  }
  sleep(1 + Math.random() * 2);
}

// Login storm: every VU signs in at the same moment with its own new account.
export function login() {
  const token = signIn(`${RUN}storm${__VU}@loadtest.example`, json());
  check(token, { 'login storm: got a token': (t) => !!t });
}

export function chat(data) {
  ok(http.post(`${BASE}/communities/${data.communityId}/chat/messages`,
    JSON.stringify({ body: `load test message ${__VU}-${__ITER}` }), json(tokenFor(data))), 'chat send');
  sleep(Number(__ENV.CHAT_SLEEP || 2));
}
