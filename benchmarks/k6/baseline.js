
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// ── Custom metrics ──────────────────────────────────────────────
const ttft = new Trend('ttft_ms', true);              // proxy: full response time
const tokensPerSec = new Trend('tokens_per_sec');
const completionErrors = new Rate('completion_errors');
const totalTokens = new Counter('total_tokens');

// ── Load shape: ramp 1→10→25, hold, ramp down ───────────────────
export const options = {
  stages: [
    { duration: '1m', target: 5 },    // warm up
    { duration: '2m', target: 10 },   // moderate load
    { duration: '2m', target: 25 },   // find the strain point
    { duration: '1m', target: 0 },    // ramp down
  ],
  thresholds: {
    // Generous for CPU baseline — this is a path test, not a perf test
    http_req_duration: ['p(95)<15000'],     // p95 under 15s
    http_req_failed:   ['rate<0.10'],     // under 10% errors
    completion_errors: ['rate<0.10'],
  },
};

// ── Config (override with -e flags at runtime) ──────────────────
const GATEWAY = __ENV.GATEWAY_URL || 'http://34.93.212.31';


const MODEL   = __ENV.MODEL || 'opt-125m';

// Shared prompt — consistent across runs for comparability
const PROMPT = 'Explain what a Kubernetes operator does in one sentence.';
const MAX_TOKENS = 32;

export default function () {
  const url = `${GATEWAY}/v1/completions`;
  const payload = JSON.stringify({
    model: MODEL,
    prompt: PROMPT,
    max_tokens: MAX_TOKENS,
    temperature: 0,    // deterministic — same work every request
  });
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${API_KEY}`,
    },
    timeout: '30s',
  };

  const start = Date.now();
  const res = http.post(url, payload, params);
  const elapsed = Date.now() - start;

  const ok = check(res, {
    'status is 200': (r) => r.status === 200,
    'has completion': (r) => {
      try { return JSON.parse(r.body).choices[0].text.length > 0; }
      catch { return false; }
    },
  });

  completionErrors.add(!ok);

  if (ok) {
    ttft.add(elapsed);
    try {
      const body = JSON.parse(res.body);
      const completionToks = body.usage.completion_tokens;
      totalTokens.add(completionToks);
      if (elapsed > 0) tokensPerSec.add(completionToks / (elapsed / 1000));
    } catch (e) { /* ignore parse errors */ }
  }

  sleep(1);  // pacing between requests per VU
}

// ── Summary → JSON for MinIO ────────────────────────────────────
export function handleSummary(data) {
  return {
    'stdout': textSummary(data),
    'baseline-results.json': JSON.stringify(data, null, 2),
  };
}

// minimal text summary (k6 doesn't bundle one in all versions)
function textSummary(data) {
  const m = data.metrics;
  const p = (metric, stat) => (m[metric]?.values?.[stat] ?? 0).toFixed(1);
  return `
═══════════════════════════════════════════
  BASELINE RESULTS (CPU / opt-125m)
═══════════════════════════════════════════
  Requests total:     ${m.http_reqs?.values?.count ?? 0}
  Req/s (avg):        ${p('http_reqs', 'rate')}
  Error rate:         ${((m.http_req_failed?.values?.rate ?? 0) * 100).toFixed(1)}%

  Latency (full response):
    p50:              ${p('http_req_duration', 'med')} ms
    p95:              ${p('http_req_duration', 'p(95)')} ms
    p99:              ${p('http_req_duration', 'p(99)')} ms

  Throughput:
    tokens/sec (avg): ${p('tokens_per_sec', 'avg')}
    total tokens:     ${m.total_tokens?.values?.count ?? 0}
═══════════════════════════════════════════
`;
}
