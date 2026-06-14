# Baseline — CPU / opt-125m

Path-validation baseline. Measures the platform path
(Envoy → LiteLLM → vLLM), not model performance.

| Metric | Value |
|---|---|
| Requests | 912 |
| Throughput | 2.5 req/s |
| Error rate | 0.0% |
| p50 latency | 3,474 ms |
| p95 latency | 4,232 ms |
| tokens/sec | 11.0 |
| Total tokens | 29,184 |

**Setup:** k6, ramp 5→10→25 VUs over 6 min, opt-125m on CPU (n2-standard-4),
loaded from MinIO registry, served via Envoy Gateway public IP.

**Key result:** 0% errors under 25 concurrent users — platform path is stable.
Latency is CPU-bound (opt-125m); GPU quantization results (Phase 3) compare
against this baseline.
