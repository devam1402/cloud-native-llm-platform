import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Counter } from 'k6/metrics';

const tokensPerSec = new Trend('tokens_per_sec');
const totalTokens = new Counter('total_tokens');

export const options = {
  stages: [
    { duration: '1m', target: 10 },
    { duration: '2m', target: 50 },
    { duration: '2m', target: 100 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<10000'],
    http_req_failed: ['rate<0.10'],
  },
};

const PROMPT = 'Explain what a Kubernetes operator does and how it differs from a Helm chart, in two short paragraphs.';

export default function () {
  const res = http.post('http://localhost:8000/v1/completions',
    JSON.stringify({ model: 'qwen2.5-7b', prompt: PROMPT, max_tokens: 128, temperature: 0 }),
    { headers: { 'Content-Type': 'application/json' }, timeout: '60s' });

  const ok = check(res, { 'status 200': (r) => r.status === 200 });
  if (ok) {
    try {
      const b = JSON.parse(res.body);
      const t = b.usage.completion_tokens;
      const e = res.timings.duration / 1000;
      totalTokens.add(t);
      if (e > 0) tokensPerSec.add(t / e);
    } catch (err) {}
  }
  sleep(0.5);
}
