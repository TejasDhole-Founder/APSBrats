"""Live API and database dashboard for the APS Brats backend (local use).

Reads the backend's /actuator/prometheus every few seconds and shows, in plain language:
  * every endpoint: hits, average / p50 / p95 / p99 time, errors, and where the total time goes
  * every database call (Spring Data repository method): calls, average / p95 / slowest time
  * Postgres itself (optional, --pg-container): cache hit rate, tables read by full scan, queries running
    right now, and the slowest SQL statements when pg_stat_statements is switched on
  * the connection pool, memory, CPU and garbage collection
  * trends over the last ~10 minutes, and a list of things worth looking at
  * "Start measuring": zero the counters so you can count the calls of one screen or one action

Usage:
    python api_dashboard.py                              # reads http://localhost:8080
    python api_dashboard.py --target http://localhost:8090
    python api_dashboard.py --pg-container apsbrats-db-1 --pg-db apsbrat_db --pg-user aps_user   # add Postgres panel
Then open http://localhost:8099.

Needs the dev profile (it exposes /actuator/prometheus and turns on the histograms this reads).
The Postgres panel runs read-only SELECTs on statistics views through `docker exec`. Standard library only.
"""
import argparse
import json
import math
import re
import subprocess
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

POLL_SECONDS = 3
HISTORY_POINTS = 200            # ~10 minutes at 3 s
PG_POLL_SECONDS = 10

# Thresholds for the "worth a look" list.
MIN_CALLS = 10                  # no "slow" verdicts from fewer calls than this
SLOW_AVG_MS = 300
SLOW_P95_MS = 1000
SLOW_REPO_AVG_MS = 50
CALLS_PER_REQUEST_WARN = 15
CALLS_PER_REQUEST_BAD = 40
HEAP_WARN = 0.85

LINE = re.compile(r'^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{(.*)\})?\s+(\S+)(?:\s+-?\d+)?$')
LABEL = re.compile(r'(\w+)="((?:[^"\\]|\\.)*)"')


# ── reading the metrics ─────────────────────────────────────────────────────

def unescape(v):
    return v.replace('\\n', '\n').replace('\\"', '"').replace('\\\\', '\\')


def parse(text):
    out = []
    for line in text.splitlines():
        if not line or line[0] == '#':
            continue
        m = LINE.match(line)
        if not m:
            continue
        name, raw, val = m.groups()
        try:
            value = float(val)
        except ValueError:
            continue
        labels = {k: unescape(v) for k, v in LABEL.findall(raw or '')}
        out.append((name, labels, value))
    return out


def new_agg():
    return {'count': 0.0, 'sum': 0.0, 'max': 0.0, 'c4': 0.0, 'c5': 0.0, 'err': 0.0, 'buckets': {}}


def add_timer(agg, name, labels, value, suffix):
    if name.endswith(suffix + '_count'):
        agg['count'] += value
    elif name.endswith(suffix + '_sum'):
        agg['sum'] += value
    elif name.endswith(suffix + '_max'):
        agg['max'] = max(agg['max'], value)
    elif name.endswith(suffix + '_bucket'):
        try:
            le = float(labels['le'])
        except (KeyError, ValueError):
            return
        agg['buckets'][le] = agg['buckets'].get(le, 0.0) + value


def snapshot(series):
    snap = {'http': {}, 'repo': {}, 'pool': {}, 'jvm': {}}
    pool, jvm = snap['pool'], snap['jvm']
    for name, lab, v in series:
        if name.startswith('http_server_requests_seconds'):
            uri = lab.get('uri', '')
            if uri.startswith('/actuator'):
                continue
            agg = snap['http'].setdefault((lab.get('method', '?'), uri), new_agg())
            add_timer(agg, name, lab, v, '_seconds')
            if name.endswith('_count'):
                status = lab.get('status', '')
                if status.startswith('4'):
                    agg['c4'] += v
                elif status.startswith('5'):
                    agg['c5'] += v
        elif name.startswith('spring_data_repository_invocations_seconds'):
            key = (lab.get('repository', '?'), lab.get('method', '?'))
            agg = snap['repo'].setdefault(key, new_agg())
            add_timer(agg, name, lab, v, '_seconds')
            if name.endswith('_count') and lab.get('state', 'SUCCESS') != 'SUCCESS':
                agg['err'] += v
        elif name.startswith('hikaricp_connections'):
            short = name[len('hikaricp_connections'):].lstrip('_')
            if short.startswith('acquire_seconds') or short.startswith('usage_seconds'):
                base = short.split('_seconds')[0]
                kind = short.rsplit('_', 1)[-1]
                if kind in ('count', 'sum'):
                    pool[base + '_' + kind] = pool.get(base + '_' + kind, 0.0) + v
                elif kind == 'max':
                    pool[base + '_max'] = max(pool.get(base + '_max', 0.0), v)
            elif short in ('active', 'idle', 'pending', 'max', 'min', 'timeout_total'):
                pool[short] = pool.get(short, 0.0) + v
        elif name == 'jvm_memory_used_bytes' and lab.get('area') == 'heap':
            jvm['heap_used'] = jvm.get('heap_used', 0.0) + v
        elif name == 'jvm_memory_max_bytes' and lab.get('area') == 'heap' and v > 0:
            jvm['heap_max'] = jvm.get('heap_max', 0.0) + v
        elif name == 'jvm_gc_pause_seconds_count':
            jvm['gc_count'] = jvm.get('gc_count', 0.0) + v
        elif name == 'jvm_gc_pause_seconds_sum':
            jvm['gc_sum'] = jvm.get('gc_sum', 0.0) + v
        elif name == 'jvm_gc_pause_seconds_max':
            jvm['gc_max'] = max(jvm.get('gc_max', 0.0), v)
        elif name in ('process_cpu_usage', 'system_cpu_usage', 'jvm_threads_live_threads',
                      'process_uptime_seconds', 'jvm_threads_peak_threads'):
            jvm[name] = v
    return snap


# ── turning counters into numbers ───────────────────────────────────────────

def diff_agg(cur, base):
    """What happened since the baseline. If the counter went backwards the app restarted: use it as is."""
    if not base or cur['count'] < base['count']:
        return cur
    return {
        'count': cur['count'] - base['count'], 'sum': cur['sum'] - base['sum'], 'max': cur['max'],
        'c4': cur['c4'] - base['c4'], 'c5': cur['c5'] - base['c5'], 'err': cur['err'] - base['err'],
        'buckets': {le: c - base['buckets'].get(le, 0.0) for le, c in cur['buckets'].items()},
    }


def quantile(buckets, count, q):
    """Estimate from a cumulative histogram; the answer is only as fine as the bucket edges."""
    if count <= 0 or not buckets:
        return None
    target = q * count
    prev_le, prev_c = 0.0, 0.0
    for le in sorted(buckets):
        c = buckets[le]
        if c >= target:
            if math.isinf(le):
                return prev_le * 1000
            if c == prev_c:
                return le * 1000
            return (prev_le + (le - prev_le) * (target - prev_c) / (c - prev_c)) * 1000
        prev_le, prev_c = le, c
    return prev_le * 1000


def row(key, agg, running_max):
    n = agg['count']
    return {
        'name': key,
        'count': int(n),
        'avgMs': agg['sum'] / n * 1000 if n else 0.0,
        'p50': quantile(agg['buckets'], n, 0.50),
        'p95': quantile(agg['buckets'], n, 0.95),
        'p99': quantile(agg['buckets'], n, 0.99),
        'maxMs': running_max * 1000,
        'totalS': agg['sum'],
        'c4': int(agg['c4']),
        'c5': int(agg['c5']),
        'err': int(agg['err']),
    }


def merge_buckets(rows_aggs):
    out = {}
    for agg in rows_aggs:
        for le, c in agg['buckets'].items():
            out[le] = out.get(le, 0.0) + c
    return out


def short_repo(name):
    return name.split('.')[-1]


# ── Postgres statistics (optional) ──────────────────────────────────────────

SEP = '\x1f'


class PgProbe:
    """Read-only statistics from Postgres through `docker exec ... psql`. Nothing is written."""

    def __init__(self, container, db, user):
        self.container, self.db, self.user = container, db, user

    def run(self, sql):
        cmd = ['docker', 'exec', '-i', self.container, 'psql', '-U', self.user, '-d', self.db,
               '-X', '-A', '-t', '-F', SEP, '-c', sql]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        if r.returncode:
            raise RuntimeError(r.stderr.strip().splitlines()[-1] if r.stderr.strip() else 'psql failed')
        return [line.split(SEP) for line in r.stdout.splitlines() if line.strip()]

    def collect(self):
        try:
            db = self.run("""SELECT coalesce(round(100.0 * sum(blks_hit) / nullif(sum(blks_hit + blks_read), 0), 2), 100),
                                    sum(xact_commit), sum(xact_rollback), sum(deadlocks), sum(temp_files), sum(numbackends)
                             FROM pg_stat_database WHERE datname = current_database()""")[0]
            tables = self.run("""SELECT relname, seq_scan, seq_tup_read, coalesce(idx_scan, 0), n_live_tup
                                 FROM pg_stat_user_tables ORDER BY seq_tup_read DESC LIMIT 8""")
            running = self.run("""SELECT round(extract(epoch FROM now() - query_start)::numeric, 2), state,
                                         left(regexp_replace(query, '\\s+', ' ', 'g'), 240)
                                  FROM pg_stat_activity
                                  WHERE datname = current_database() AND pid <> pg_backend_pid()
                                    AND state <> 'idle' AND query_start IS NOT NULL
                                  ORDER BY query_start LIMIT 5""")
            has_stmts = self.run("SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements'")
            statements, hint = None, ('For per-SQL timings enable pg_stat_statements: start Postgres with '
                                      '"-c shared_preload_libraries=pg_stat_statements", then run '
                                      'CREATE EXTENSION pg_stat_statements; in this database.')
            if has_stmts:
                rows = self.run("""SELECT calls, round(total_exec_time::numeric, 1), round(mean_exec_time::numeric, 2),
                                          round(max_exec_time::numeric, 1), rows,
                                          left(regexp_replace(query, '\\s+', ' ', 'g'), 400)
                                   FROM pg_stat_statements
                                   WHERE dbid = (SELECT oid FROM pg_database WHERE datname = current_database())
                                     AND query NOT ILIKE '%pg_stat_%'
                                   ORDER BY total_exec_time DESC LIMIT 12""")
                statements = [{'calls': int(c), 'totalMs': float(t), 'meanMs': float(m), 'maxMs': float(x),
                               'rows': int(r), 'query': q} for c, t, m, x, r, q in rows]
                hint = None
            return {
                'ok': True, 'cacheHitPct': float(db[0]), 'commits': int(db[1]), 'rollbacks': int(db[2]),
                'deadlocks': int(db[3]), 'tempFiles': int(db[4]), 'connections': int(db[5]),
                'tables': [{'name': n, 'seqScan': int(a), 'seqRows': int(b), 'idxScan': int(c), 'liveRows': int(d)}
                           for n, a, b, c, d in tables],
                'running': [{'seconds': float(a), 'state': b, 'query': c} for a, b, c in running],
                'statements': statements, 'statementsHint': hint,
            }
        except Exception as e:
            return {'ok': False, 'error': f'Could not read Postgres statistics: {e}'}


# ── the sampler: polls, keeps history, builds what the page shows ───────────

class Sampler:
    def __init__(self, target, pg=None):
        self.target = target
        self.pg = pg
        self.pg_state = None
        self.pg_checked = 0.0
        self.lock = threading.Lock()
        self.latest = None            # last raw snapshot
        self.baseline = None          # snapshot taken by "Start measuring"
        self.baseline_time = None
        self.running_max = {}         # ('http'|'repo', key) -> slowest seen since baseline / dashboard start
        self.prev_totals = None
        self.history = deque(maxlen=HISTORY_POINTS)
        self.state = {'error': 'Waiting for the first reading…', 'target': target}

    def fetch(self):
        req = urllib.request.Request(self.target + '/actuator/prometheus')
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.read().decode('utf-8', 'replace')

    def start_measuring(self):
        with self.lock:
            if self.latest is not None:
                self.baseline = self.latest
                self.baseline_time = time.time()
                self.running_max = {}

    def stop_measuring(self):
        with self.lock:
            self.baseline = None
            self.baseline_time = None
            self.running_max = {}

    def loop(self):
        while True:
            try:
                snap = snapshot(parse(self.fetch()))
                if self.pg and time.time() - self.pg_checked >= PG_POLL_SECONDS:
                    self.pg_checked = time.time()
                    pg_state = self.pg.collect()
                    with self.lock:
                        self.pg_state = pg_state
                with self.lock:
                    self.latest = snap
                    state = self.build(snap)
                    self.state = state
            except urllib.error.HTTPError as e:
                self.set_error(f'The backend refused /actuator/prometheus (HTTP {e.code}). '
                               'Restart the app with the dev profile so the dev-only metrics switch is on.')
            except (urllib.error.URLError, OSError) as e:
                self.set_error(f'Cannot reach {self.target} ({e}). Is the app running?')
            except Exception as e:  # keep the dashboard alive whatever the data looks like
                self.set_error(f'Could not read the metrics: {e!r}')
            time.sleep(POLL_SECONDS)

    def set_error(self, msg):
        with self.lock:
            self.state = {'error': msg, 'target': self.target}

    # Called with the lock held.
    def build(self, snap):
        base = self.baseline
        for kind in ('http', 'repo'):
            for key, agg in snap[kind].items():
                k = (kind, key)
                self.running_max[k] = max(self.running_max.get(k, 0.0), agg['max'])

        def delta(kind):
            out = {}
            for key, agg in snap[kind].items():
                d = diff_agg(agg, base[kind].get(key) if base else None)
                if d['count'] > 0:
                    out[key] = d
            return out

        http, repo = delta('http'), delta('repo')
        http_total = sum(a['count'] for a in http.values())
        http_time = sum(a['sum'] for a in http.values())
        repo_total = sum(a['count'] for a in repo.values())
        repo_time = sum(a['sum'] for a in repo.values())

        endpoints = []
        for (method, uri), agg in http.items():
            r = row(f'{method} {uri}', agg, self.running_max.get(('http', (method, uri)), 0.0))
            r['sharePct'] = agg['sum'] / http_time * 100 if http_time else 0.0
            endpoints.append(r)
        endpoints.sort(key=lambda r: r['count'], reverse=True)

        repos = []
        for (repository, method), agg in repo.items():
            r = row(f'{short_repo(repository)}.{method}', agg, self.running_max.get(('repo', (repository, method)), 0.0))
            r['sharePct'] = agg['sum'] / repo_time * 100 if repo_time else 0.0
            repos.append(r)
        repos.sort(key=lambda r: r['totalS'], reverse=True)

        pool, jvm = snap['pool'], snap['jvm']
        acq_n = pool.get('acquire_count', 0.0)
        use_n = pool.get('usage_count', 0.0)
        pool_out = {
            'active': int(pool.get('active', 0)), 'idle': int(pool.get('idle', 0)),
            'pending': int(pool.get('pending', 0)), 'max': int(pool.get('max', 0)),
            'timeouts': int(pool.get('timeout_total', 0)),
            'acquireAvgMs': pool.get('acquire_sum', 0.0) / acq_n * 1000 if acq_n else 0.0,
            'acquireMaxMs': pool.get('acquire_max', 0.0) * 1000,
            'usageAvgMs': pool.get('usage_sum', 0.0) / use_n * 1000 if use_n else 0.0,
            'usageMaxMs': pool.get('usage_max', 0.0) * 1000,
        }
        heap_used, heap_max = jvm.get('heap_used', 0.0), jvm.get('heap_max', 0.0)
        gc_n = jvm.get('gc_count', 0.0)
        jvm_out = {
            'heapUsedMb': heap_used / 1048576, 'heapMaxMb': heap_max / 1048576,
            'heapPct': heap_used / heap_max * 100 if heap_max else 0.0,
            'cpuPct': jvm.get('process_cpu_usage', 0.0) * 100,
            'systemCpuPct': jvm.get('system_cpu_usage', 0.0) * 100,
            'threads': int(jvm.get('jvm_threads_live_threads', 0)),
            'uptimeS': jvm.get('process_uptime_seconds', 0.0),
            'gcCount': int(gc_n), 'gcAvgMs': jvm.get('gc_sum', 0.0) / gc_n * 1000 if gc_n else 0.0,
            'gcMaxMs': jvm.get('gc_max', 0.0) * 1000,
        }

        # Trend points always come from raw totals so the graphs keep moving after "Start measuring".
        raw_http_n = sum(a['count'] for a in snap['http'].values())
        raw_http_t = sum(a['sum'] for a in snap['http'].values())
        raw_err = sum(a['c4'] + a['c5'] for a in snap['http'].values())
        raw_repo_n = sum(a['count'] for a in snap['repo'].values())
        raw_repo_t = sum(a['sum'] for a in snap['repo'].values())
        now = time.time()
        totals = (now, raw_http_n, raw_http_t, raw_err, raw_repo_n, raw_repo_t)
        if self.prev_totals and raw_http_n >= self.prev_totals[1]:
            dt = max(now - self.prev_totals[0], 0.001)
            dn = raw_http_n - self.prev_totals[1]
            dr = raw_repo_n - self.prev_totals[4]
            self.history.append({
                't': now, 'rps': dn / dt,
                'avgMs': (raw_http_t - self.prev_totals[2]) / dn * 1000 if dn else 0.0,
                'errPerS': (raw_err - self.prev_totals[3]) / dt,
                'dbPerS': dr / dt,
                'dbAvgMs': (raw_repo_t - self.prev_totals[5]) / dr * 1000 if dr else 0.0,
                'poolActive': pool_out['active'], 'heapMb': jvm_out['heapUsedMb'],
            })
        elif self.prev_totals:
            self.history.clear()   # the app restarted
        self.prev_totals = totals

        recent = list(self.history)[-10:]
        req_per_min = sum(p['rps'] for p in recent) / len(recent) * 60 if recent else 0.0

        overall_buckets = merge_buckets(http.values())
        c4 = sum(a['c4'] for a in http.values())
        c5 = sum(a['c5'] for a in http.values())
        cards = {
            'requests': int(http_total), 'reqPerMin': req_per_min,
            'avgMs': http_time / http_total * 1000 if http_total else 0.0,
            'p95Ms': quantile(overall_buckets, http_total, 0.95),
            'errors4': int(c4), 'errors5': int(c5),
            'dbCalls': int(repo_total),
            'dbPerRequest': repo_total / http_total if http_total else 0.0,
            'dbTimePct': repo_time / http_time * 100 if http_time else 0.0,
            'dbAvgMs': repo_time / repo_total * 1000 if repo_total else 0.0,
        }

        return {
            'target': self.target, 'time': now, 'error': None,
            'baselineTime': self.baseline_time,
            'cards': cards, 'endpoints': endpoints, 'repos': repos,
            'pool': pool_out, 'jvm': jvm_out, 'pg': self.pg_state,
            'insights': insights(cards, endpoints, repos, pool_out, jvm_out, self.pg_state),
            'history': list(self.history),
        }


# ── plain-language findings ─────────────────────────────────────────────────

def insights(cards, endpoints, repos, pool, jvm, pg):
    out = []

    def add(level, text):
        out.append({'level': level, 'text': text})

    if cards['requests'] == 0:
        add('info', 'No requests yet. Use the app and this fills in. Press "Start measuring" first to count one screen or action on its own.')
        return out

    def slowest(r):
        return f" (slowest {r['maxMs']:.0f} ms)" if r['maxMs'] > 0 else ''

    # Fewer than MIN_CALLS calls is mostly warm-up (the first calls after a start are always slow).
    for e in endpoints:
        if e['count'] < MIN_CALLS:
            continue
        if e['p95'] is not None and e['p95'] > SLOW_P95_MS:
            add('warn', f"{e['name']}: 1 in 20 calls takes over {e['p95']:.0f} ms{slowest(e)}.")
        elif e['avgMs'] > SLOW_AVG_MS:
            add('warn', f"{e['name']}: slow on average, {e['avgMs']:.0f} ms over {e['count']} calls.")
    total_time = sum(e['totalS'] for e in endpoints)
    for e in endpoints:
        if e['count'] >= 10 and total_time and e['totalS'] / total_time > 0.4:
            add('info', f"{e['name']} takes {e['sharePct']:.0f}% of all request time: the best place to speed things up.")
    for e in endpoints:
        if e['c5']:
            add('bad', f"{e['name']}: {e['c5']} server error(s) (5xx). Check the server log.")
        if e['count'] >= 5 and e['c4'] / e['count'] > 0.2:
            note = ' Mostly sign-in / expired tokens.' if e['c4'] and '/auth' in e['name'] else ''
            add('info', f"{e['name']}: {e['c4']} of {e['count']} calls were refused or not found (4xx).{note}")
    stray = [e for e in endpoints if e['name'].endswith(' /**') or e['name'].endswith(' UNKNOWN')]
    if stray:
        n = sum(e['count'] for e in stray)
        add('info', f"{n} request(s) hit a URL that does not exist. A wrong path in the app, or a browser/bot probing.")

    per = cards['dbPerRequest']
    if per > CALLS_PER_REQUEST_BAD:
        add('bad', f"{per:.0f} database calls per request on average. That is very likely repeated queries (N+1) or duplicated reads.")
    elif per > CALLS_PER_REQUEST_WARN:
        add('warn', f"{per:.0f} database calls per request on average. Worth checking for repeated queries.")
    if cards['dbTimePct'] > 60 and cards['dbCalls'] >= 20:
        add('info', f"{cards['dbTimePct']:.0f}% of request time is spent in the database. Indexes and query count matter more than code here.")
    for r in repos:
        if r['count'] >= MIN_CALLS and r['avgMs'] > SLOW_REPO_AVG_MS:
            add('warn', f"{r['name']}: {r['avgMs']:.0f} ms per call over {r['count']} calls{slowest(r)}.")
        if r['err']:
            add('bad', f"{r['name']}: {r['err']} failed call(s).")

    if pool['pending'] > 0:
        add('bad', f"{pool['pending']} request(s) waiting for a database connection. The pool ({pool['max']}) is full.")
    elif pool['max'] and pool['active'] >= pool['max'] - 1:
        add('warn', f"The database pool is almost full ({pool['active']}/{pool['max']} in use).")
    if pool['acquireMaxMs'] > 100:
        add('warn', f"Waiting for a database connection took up to {pool['acquireMaxMs']:.0f} ms recently.")
    if pool['timeouts']:
        add('bad', f"{pool['timeouts']} database connection timeout(s) since start.")
    if jvm['heapPct'] > HEAP_WARN * 100:
        add('warn', f"Memory is {jvm['heapPct']:.0f}% full ({jvm['heapUsedMb']:.0f} of {jvm['heapMaxMb']:.0f} MB).")
    if pg and pg.get('ok'):
        if pg['cacheHitPct'] is not None and pg['cacheHitPct'] < 95:
            add('warn', f"Postgres answers only {pg['cacheHitPct']:.1f}% of reads from memory (healthy is 99%+). It is reading the disk a lot.")
        if pg['deadlocks']:
            add('bad', f"{pg['deadlocks']} database deadlock(s) since the stats were last reset.")
        for t in pg['tables']:
            if t['liveRows'] >= 10000 and t['seqScan'] >= 20 and t['seqScan'] > t['idxScan']:
                add('warn', f"Table {t['name']} ({t['liveRows']:,} rows) was read by scanning every row {t['seqScan']:,} times, more than by index ({t['idxScan']:,}). Likely a missing index.")
        for q in pg['running']:
            if q['seconds'] > 2:
                add('warn', f"A query has been running for {q['seconds']:.1f} s: {q['query'][:120]}")
        if pg['statements']:
            top = pg['statements'][0]
            if top['meanMs'] > 100 and top['calls'] >= MIN_CALLS:
                add('warn', f"Slowest SQL on average: {top['meanMs']:.0f} ms over {top['calls']:,} calls: {top['query'][:120]}")
    if not out:
        add('ok', 'Nothing stands out. Latency, errors, database calls and the pool all look healthy.')
    return out


# ── the page ────────────────────────────────────────────────────────────────

PAGE = r"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>APS Brats API</title>
<style>
  :root { --crimson:#7b1414; --ink:#2b1f1f; --muted:#8a7070; --line:#eadcdc; --tint:#f3ecec; --bg:#fbf8f6; --card:#fff;
          --ok:#2e7d32; --info:#1565c0; --warn:#b26a00; --bad:#b00020; }
  * { box-sizing: border-box; }
  body { font-family: system-ui, sans-serif; margin: 0; color: var(--ink); background: var(--bg); }
  header { background: var(--crimson); color: #fff; padding: 14px 24px; display: flex; flex-wrap: wrap; gap: 12px; align-items: center; }
  header h1 { margin: 0; font-size: 18px; flex: 1; min-width: 200px; }
  header .meta { font-size: 12px; opacity: .85; }
  button { font: inherit; font-size: 13px; padding: 7px 14px; border-radius: 18px; border: 1px solid #fff; background: transparent; color: #fff; cursor: pointer; }
  button.primary { background: #fff; color: var(--crimson); font-weight: 600; }
  main { padding: 18px 24px 40px; max-width: 1400px; margin: 0 auto; }
  .banner { padding: 10px 14px; border-radius: 10px; font-size: 13px; margin-bottom: 14px; background: var(--tint); }
  .banner.err { background: #fde8ea; color: var(--bad); }
  .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; margin-bottom: 18px; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 10px 14px; }
  .card b { display: block; font-size: 22px; font-variant-numeric: tabular-nums; }
  .card span { font-size: 12px; color: var(--muted); }
  .card.warn b { color: var(--warn); } .card.bad b { color: var(--bad); } .card.ok b { color: var(--ok); }
  h2 { font-size: 15px; margin: 22px 0 8px; color: var(--crimson); }
  h2 small { font-weight: 400; color: var(--muted); font-size: 12px; margin-left: 6px; }
  .grid2 { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 12px; }
  .panel { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 12px 14px; }
  .panel h3 { margin: 0 0 6px; font-size: 12px; color: var(--muted); font-weight: 600; text-transform: uppercase; letter-spacing: .04em; }
  .panel .big { font-size: 20px; font-weight: 600; font-variant-numeric: tabular-nums; }
  svg.spark { width: 100%; height: 56px; display: block; }
  table { width: 100%; border-collapse: collapse; background: var(--card); border: 1px solid var(--line); border-radius: 12px; overflow: hidden; }
  th, td { text-align: left; padding: 7px 10px; font-size: 12.5px; border-bottom: 1px solid #f0e6e6; vertical-align: middle; }
  th { background: var(--tint); color: #5c0f0f; font-weight: 600; cursor: default; white-space: nowrap; }
  th.sortable { cursor: pointer; } th.sortable:hover { text-decoration: underline; }
  td.num { text-align: right; font-variant-numeric: tabular-nums; white-space: nowrap; }
  td.name { max-width: 380px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .bar { height: 9px; background: #b44040; border-radius: 5px; min-width: 2px; }
  .barcell { width: 140px; }
  .slow { color: var(--warn); font-weight: 600; } .vslow { color: var(--bad); font-weight: 600; }
  .muted { color: var(--muted); }
  .ins { list-style: none; padding: 0; margin: 0; display: grid; gap: 6px; }
  .ins li { padding: 8px 12px; border-radius: 10px; font-size: 13px; background: var(--card); border: 1px solid var(--line); border-left-width: 5px; }
  .ins li.ok { border-left-color: var(--ok); } .ins li.info { border-left-color: var(--info); }
  .ins li.warn { border-left-color: var(--warn); } .ins li.bad { border-left-color: var(--bad); }
  pre.sql { margin: 0; white-space: pre-wrap; word-break: break-word; font-size: 11.5px; max-height: 110px; overflow: auto; }
  .scroll { max-height: 440px; overflow: auto; border-radius: 12px; }
  .hint { font-size: 12px; color: var(--muted); margin: 4px 0 8px; }
</style></head>
<body>
<header>
  <h1>APS Brats API &amp; database</h1>
  <span class="meta" id="meta"></span>
  <button class="primary" id="startBtn">Start measuring</button>
  <button id="stopBtn" style="display:none">Back to since app start</button>
</header>
<main>
  <div class="banner" id="banner">Loading…</div>
  <div class="cards" id="cards"></div>

  <h2>Worth a look</h2>
  <ul class="ins" id="insights"></ul>

  <h2>Trends <small>last ~10 minutes, every 3 s</small></h2>
  <div class="grid2" id="trends"></div>

  <h2>Endpoints <small>what the app asks the server for</small></h2>
  <div class="hint">Times are in milliseconds. p95 means 95 out of 100 calls were faster than this. Click a heading to sort.
    <b>Slowest</b> is the slowest call seen since the page was opened (or since you pressed Start measuring).</div>
  <div class="scroll"><table id="endpointTable"></table></div>

  <h2>Database calls <small>every repository method the server ran</small></h2>
  <div class="hint">Each call includes the SQL and the time to build the Java objects. The "database calls per request" card above is the quickest way to spot repeated queries.</div>
  <div class="scroll"><table id="repoTable"></table></div>

  <h2>Postgres <small>read from the database's own statistics, refreshed every 10 s</small></h2>
  <div id="pg"></div>

  <h2>Database pool, memory and CPU</h2>
  <div class="grid2" id="system"></div>
</main>
<script>
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const fmt = (n, d=0) => n == null ? '–' : Number(n).toLocaleString(undefined, {minimumFractionDigits: d, maximumFractionDigits: d});
const ms = n => n == null ? '–' : (n >= 1000 ? fmt(n / 1000, 2) + ' s' : fmt(n, n < 10 ? 1 : 0) + ' ms');
const cls = (v, warn, bad) => v == null ? '' : v > bad ? 'vslow' : v > warn ? 'slow' : '';
let sortKey = {endpoint: 'count', repo: 'totalS'};

function spark(points, key, color, unit) {
  if (!points.length) return '<span class="muted">no data yet</span>';
  const vals = points.map(p => p[key]); const max = Math.max(1e-9, ...vals);
  const w = 300, h = 56, step = vals.length > 1 ? w / (vals.length - 1) : w;
  const pts = vals.map((v, i) => `${(i * step).toFixed(1)},${(h - 4 - (v / max) * (h - 10)).toFixed(1)}`).join(' ');
  const last = vals[vals.length - 1];
  return `<div class="big">${fmt(last, last < 10 ? 1 : 0)} <span class="muted" style="font-size:12px">${unit}</span></div>
    <svg class="spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none"><polyline fill="none" stroke="${color}" stroke-width="2" points="${pts}"/></svg>
    <div class="muted" style="font-size:11px">peak ${fmt(max, max < 10 ? 1 : 0)} ${unit}</div>`;
}

function tableHtml(kind, rows, cols) {
  const sk = sortKey[kind];
  const sorted = [...rows].sort((a, b) => (b[sk] ?? -1) - (a[sk] ?? -1));
  const maxShare = Math.max(1, ...rows.map(r => r.sharePct));
  const head = cols.map(c => `<th class="${c.key ? 'sortable' : ''} ${c.num ? 'num' : ''}" data-kind="${kind}" data-key="${c.key || ''}">${c.label}${sk === c.key ? ' ▾' : ''}</th>`).join('');
  const body = sorted.map(r => '<tr>' + cols.map(c => c.render(r, maxShare)).join('') + '</tr>').join('')
    || `<tr><td colspan="${cols.length}" class="muted">Nothing yet.</td></tr>`;
  return `<thead><tr>${head}</tr></thead><tbody>${body}</tbody>`;
}

const endpointCols = [
  {label: 'Endpoint', render: r => `<td class="name" title="${esc(r.name)}">${esc(r.name)}</td>`},
  {label: 'Hits', key: 'count', num: 1, render: r => `<td class="num">${fmt(r.count)}</td>`},
  {label: 'Avg', key: 'avgMs', num: 1, render: r => `<td class="num ${cls(r.avgMs, 300, 1000)}">${ms(r.avgMs)}</td>`},
  {label: 'p50', key: 'p50', num: 1, render: r => `<td class="num">${ms(r.p50)}</td>`},
  {label: 'p95', key: 'p95', num: 1, render: r => `<td class="num ${cls(r.p95, 1000, 3000)}">${ms(r.p95)}</td>`},
  {label: 'p99', key: 'p99', num: 1, render: r => `<td class="num">${ms(r.p99)}</td>`},
  {label: 'Slowest', key: 'maxMs', num: 1, render: r => `<td class="num ${cls(r.maxMs, 1000, 3000)}">${ms(r.maxMs)}</td>`},
  {label: '4xx', key: 'c4', num: 1, render: r => `<td class="num ${r.c4 ? 'slow' : 'muted'}">${r.c4}</td>`},
  {label: '5xx', key: 'c5', num: 1, render: r => `<td class="num ${r.c5 ? 'vslow' : 'muted'}">${r.c5}</td>`},
  {label: 'Total time', key: 'totalS', num: 1, render: r => `<td class="num">${fmt(r.totalS, 2)} s</td>`},
  {label: 'Share of time', key: 'sharePct', render: (r, m) => `<td class="barcell"><div class="bar" style="width:${(r.sharePct / m * 100).toFixed(1)}%" title="${r.sharePct.toFixed(1)}%"></div></td>`},
];
const repoCols = [
  {label: 'Database call', render: r => `<td class="name" title="${esc(r.name)}">${esc(r.name)}</td>`},
  {label: 'Calls', key: 'count', num: 1, render: r => `<td class="num">${fmt(r.count)}</td>`},
  {label: 'Avg', key: 'avgMs', num: 1, render: r => `<td class="num ${cls(r.avgMs, 50, 200)}">${ms(r.avgMs)}</td>`},
  {label: 'p95', key: 'p95', num: 1, render: r => `<td class="num ${cls(r.p95, 100, 400)}">${ms(r.p95)}</td>`},
  {label: 'Slowest', key: 'maxMs', num: 1, render: r => `<td class="num ${cls(r.maxMs, 200, 1000)}">${ms(r.maxMs)}</td>`},
  {label: 'Failed', key: 'err', num: 1, render: r => `<td class="num ${r.err ? 'vslow' : 'muted'}">${r.err}</td>`},
  {label: 'Total time', key: 'totalS', num: 1, render: r => `<td class="num">${fmt(r.totalS, 2)} s</td>`},
  {label: 'Share of DB time', key: 'sharePct', render: (r, m) => `<td class="barcell"><div class="bar" style="width:${(r.sharePct / m * 100).toFixed(1)}%" title="${r.sharePct.toFixed(1)}%"></div></td>`},
];

function renderPg(pg) {
  const el = document.getElementById('pg');
  if (!pg) { el.innerHTML = '<div class="panel muted">Not connected. Start the dashboard with <code>--pg-container &lt;docker container&gt; --pg-db &lt;database&gt; --pg-user &lt;user&gt;</code> to see Postgres statistics here.</div>'; return; }
  if (!pg.ok) { el.innerHTML = `<div class="banner err">${esc(pg.error)}</div>`; return; }
  const kv = rows => '<table style="border:0">' + rows.map(([k, v]) => `<tr><td class="muted">${k}</td><td class="num">${v}</td></tr>`).join('') + '</table>';
  const tables = pg.tables.map(t => `<tr><td class="name">${esc(t.name)}</td><td class="num">${fmt(t.liveRows)}</td>
      <td class="num ${t.liveRows >= 10000 && t.seqScan > t.idxScan ? 'slow' : ''}">${fmt(t.seqScan)}</td><td class="num">${fmt(t.seqRows)}</td><td class="num">${fmt(t.idxScan)}</td></tr>`).join('');
  const running = pg.running.length
    ? pg.running.map(q => `<tr><td class="num ${q.seconds > 2 ? 'slow' : ''}">${fmt(q.seconds, 1)} s</td><td>${esc(q.state)}</td><td class="name" title="${esc(q.query)}">${esc(q.query)}</td></tr>`).join('')
    : '<tr><td colspan="3" class="muted">No query is running right now.</td></tr>';
  const stmts = pg.statements
    ? `<div class="scroll"><table><thead><tr><th>SQL statement</th><th class="num">Calls</th><th class="num">Avg</th><th class="num">Slowest</th><th class="num">Total time</th><th class="num">Rows</th></tr></thead><tbody>` +
      pg.statements.map(q => `<tr><td class="name" style="max-width:640px" title="${esc(q.query)}">${esc(q.query)}</td><td class="num">${fmt(q.calls)}</td>
        <td class="num ${cls(q.meanMs, 50, 200)}">${ms(q.meanMs)}</td><td class="num ${cls(q.maxMs, 200, 1000)}">${ms(q.maxMs)}</td><td class="num">${fmt(q.totalMs / 1000, 2)} s</td><td class="num">${fmt(q.rows)}</td></tr>`).join('') + '</tbody></table></div>'
    : `<div class="panel muted">${esc(pg.statementsHint || '')}</div>`;
  el.innerHTML = `<div class="grid2">
      <div class="panel"><h3>Health</h3>${kv([
        ['reads answered from memory', fmt(pg.cacheHitPct, 1) + '%'], ['open connections', pg.connections],
        ['commits / rollbacks', fmt(pg.commits) + ' / ' + fmt(pg.rollbacks)], ['deadlocks', pg.deadlocks], ['temp files written', pg.tempFiles]])}</div>
      <div class="panel"><h3>Running right now</h3><table style="border:0"><tbody>${running}</tbody></table></div>
    </div>
    <h2 style="margin-top:14px">Slowest SQL <small>by total time</small></h2>${stmts}
    <h2 style="margin-top:14px">Tables read by scanning every row <small>a high count on a big table usually means a missing index</small></h2>
    <div class="scroll"><table><thead><tr><th>Table</th><th class="num">Rows</th><th class="num">Full scans</th><th class="num">Rows read by those scans</th><th class="num">Index lookups</th></tr></thead><tbody>${tables}</tbody></table></div>`;
}

let last = null;
function render(d) {
  last = d;
  const banner = document.getElementById('banner');
  if (d.error) { banner.className = 'banner err'; banner.textContent = d.error; return; }
  const since = d.baselineTime ? `Counting since you pressed Start measuring, ${Math.round(Date.now() / 1000 - d.baselineTime)} s ago.` : 'Counting everything since the app started.';
  banner.className = 'banner';
  banner.textContent = since + ' Backend ' + d.target + ' · updated ' + new Date(d.time * 1000).toLocaleTimeString();
  document.getElementById('meta').textContent = 'uptime ' + (d.jvm.uptimeS >= 3600 ? fmt(d.jvm.uptimeS / 3600, 1) + ' h' : fmt(d.jvm.uptimeS / 60, 0) + ' min');
  document.getElementById('startBtn').textContent = d.baselineTime ? 'Restart measuring' : 'Start measuring';
  document.getElementById('stopBtn').style.display = d.baselineTime ? '' : 'none';

  const c = d.cards;
  const card = (v, label, level) => `<div class="card ${level || ''}"><b>${v}</b><span>${label}</span></div>`;
  document.getElementById('cards').innerHTML = [
    card(fmt(c.requests), 'API requests'),
    card(fmt(c.reqPerMin, c.reqPerMin < 10 ? 1 : 0), 'requests per minute (last 30 s)'),
    card(ms(c.avgMs), 'average time per request', c.avgMs > 300 ? 'warn' : ''),
    card(ms(c.p95Ms), 'p95 (slowest 5% start here)', c.p95Ms > 1000 ? 'warn' : ''),
    card(fmt(c.errors4), 'refused / not found (4xx)', c.errors4 ? 'warn' : ''),
    card(fmt(c.errors5), 'server errors (5xx)', c.errors5 ? 'bad' : 'ok'),
    card(fmt(c.dbCalls), 'database calls'),
    card(fmt(c.dbPerRequest, 1), 'database calls per request', c.dbPerRequest > 40 ? 'bad' : c.dbPerRequest > 15 ? 'warn' : ''),
    card(ms(c.dbAvgMs), 'average database call'),
    card(fmt(c.dbTimePct, 0) + '%', 'of request time is the database'),
    card(d.pool.active + ' / ' + d.pool.max, 'database connections in use', d.pool.pending ? 'bad' : ''),
    card(fmt(d.jvm.heapPct, 0) + '%', 'memory used', d.jvm.heapPct > 85 ? 'warn' : ''),
  ].join('');

  document.getElementById('insights').innerHTML = d.insights.map(i => `<li class="${i.level}">${esc(i.text)}</li>`).join('');

  const t = d.history;
  document.getElementById('trends').innerHTML = [
    ['Requests per second', 'rps', '#7b1414', 'req/s'], ['Average time per request', 'avgMs', '#b44040', 'ms'],
    ['Errors per second', 'errPerS', '#b00020', 'err/s'], ['Database calls per second', 'dbPerS', '#1565c0', 'calls/s'],
    ['Average database call', 'dbAvgMs', '#2e7d32', 'ms'], ['Connections in use', 'poolActive', '#b26a00', 'conn'],
    ['Memory used', 'heapMb', '#6a1b9a', 'MB'],
  ].map(([title, key, color, unit]) => `<div class="panel"><h3>${title}</h3>${spark(t, key, color, unit)}</div>`).join('');

  document.getElementById('endpointTable').innerHTML = tableHtml('endpoint', d.endpoints, endpointCols);
  document.getElementById('repoTable').innerHTML = tableHtml('repo', d.repos, repoCols);

  renderPg(d.pg);

  const p = d.pool, j = d.jvm;
  const kv = (rows) => '<table style="border:0">' + rows.map(([k, v]) => `<tr><td class="muted">${k}</td><td class="num">${v}</td></tr>`).join('') + '</table>';
  document.getElementById('system').innerHTML = [
    `<div class="panel"><h3>Database connection pool</h3>${kv([
      ['in use / idle / max', `${p.active} / ${p.idle} / ${p.max}`], ['waiting for a connection', p.pending],
      ['time to get a connection (avg / slowest)', `${ms(p.acquireAvgMs)} / ${ms(p.acquireMaxMs)}`],
      ['time a connection is held (avg / slowest)', `${ms(p.usageAvgMs)} / ${ms(p.usageMaxMs)}`], ['timeouts', p.timeouts]])}</div>`,
    `<div class="panel"><h3>Memory, CPU, garbage collection</h3>${kv([
      ['memory used', `${fmt(j.heapUsedMb)} of ${fmt(j.heapMaxMb)} MB`], ['app CPU / machine CPU', `${fmt(j.cpuPct, 0)}% / ${fmt(j.systemCpuPct, 0)}%`],
      ['threads', j.threads], ['garbage collections', j.gcCount], ['pause (avg / slowest)', `${ms(j.gcAvgMs)} / ${ms(j.gcMaxMs)}`]])}</div>`,
  ].join('');
}

async function refresh() {
  try { render(await (await fetch('/data')).json()); }
  catch (e) { const b = document.getElementById('banner'); b.className = 'banner err'; b.textContent = 'The dashboard server stopped answering: ' + e.message; }
}
document.addEventListener('click', e => {
  const th = e.target.closest('th.sortable');
  if (th && last) { sortKey[th.dataset.kind] = th.dataset.key; render(last); }
});
document.getElementById('startBtn').onclick = async () => { await fetch('/start', {method: 'POST'}); setTimeout(refresh, 300); };
document.getElementById('stopBtn').onclick = async () => { await fetch('/stop', {method: 'POST'}); setTimeout(refresh, 300); };
refresh(); setInterval(refresh, 3000);
</script></body></html>
"""


class Handler(BaseHTTPRequestHandler):
    sampler = None

    def _send(self, code, ctype, payload):
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path.startswith('/data'):
            with self.sampler.lock:
                state = self.sampler.state
            self._send(200, 'application/json', json.dumps(state).encode())
        else:
            self._send(200, 'text/html; charset=utf-8', PAGE.encode())

    def do_POST(self):
        if self.path.startswith('/start'):
            self.sampler.start_measuring()
        elif self.path.startswith('/stop'):
            self.sampler.stop_measuring()
        self._send(200, 'application/json', b'{}')

    def log_message(self, fmt, *args):
        return


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--target', default='http://localhost:8080', help='backend base URL')
    ap.add_argument('--port', type=int, default=8099, help='dashboard port')
    ap.add_argument('--pg-container', help='docker container running Postgres (adds the Postgres panel)')
    ap.add_argument('--pg-db', default='apsbrat_db', help='database name')
    ap.add_argument('--pg-user', default='aps_user', help='database user')
    args = ap.parse_args()
    pg = PgProbe(args.pg_container, args.pg_db, args.pg_user) if args.pg_container else None
    sampler = Sampler(args.target.rstrip('/'), pg)
    Handler.sampler = sampler
    threading.Thread(target=sampler.loop, daemon=True).start()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), Handler)
    print(f'Dashboard: http://localhost:{args.port}  (reading {sampler.target})')
    server.serve_forever()


if __name__ == '__main__':
    main()
