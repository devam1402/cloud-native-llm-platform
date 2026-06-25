# Cloud-Native LLM Inference Platform

A production-style, GitOps-managed Kubernetes platform for serving LLMs on GKE —
self-service deployment, cost-optimized GPU usage, full observability, and
published load-test baselines.

Built to demonstrate AI Platform / MLOps / SRE engineering — not a tutorial replay,
but a platform debugged through real failures, documented in [FAILURES.md](./FAILURES.md).

![Architecture](./docs/architecture/architecture.png)

---

## Live Platform

- Serving on a public IP: **Envoy Gateway → LiteLLM → vLLM**
- Every component deployed via **ArgoCD GitOps** (zero manual kubectl after bootstrap)
- Models served from an **in-cluster MinIO registry** (no external CDN at runtime)

## Baseline (k6 load test)

CPU path-validation baseline — Envoy → LiteLLM → vLLM, opt-125m on n2-standard-4:

| Metric | Value |
|---|---|
| Requests | 912 |
| Error rate | **0.0%** under 25 concurrent users |
| p50 latency | 3,474 ms |
| p95 latency | 4,232 ms |
| Throughput | 11 tokens/sec |

*Latency is CPU-bound (opt-125m). GPU quantization benchmarks compare against this baseline.*

---

## Stack

| Layer | Tool | Why |
|---|---|---|
| Infrastructure | Terraform + GKE | IaC, remote state, least-privilege IAM |
| Delivery | ArgoCD (app-of-apps) | GitOps — Git is the source of truth |
| Serving | vLLM | OpenAI-compatible LLM inference |
| Gateway | LiteLLM | Auth, cost tracking, multi-model routing |
| Ingress | Envoy Gateway | Kubernetes Gateway API, canary-capable |
| Registry | MinIO | In-cluster model + benchmark store |
| Observability | Prometheus + Grafana | Metrics, dashboards, SLOs |
| Load testing | k6 | Reproducible baselines, CI-gateable |

**Deliberately cut** (see [docs/DECISIONS.md](./docs/DECISIONS.md)): Istio (Envoy
suffices without service-mesh tax), Kubeflow/Kueue (training-platform scope —
this is inference-only), Knative (RawDeployment avoids cold-start variance).

---

## Architecture Decisions

Documented as ADRs in [docs/DECISIONS.md](./docs/DECISIONS.md):

- **Envoy Gateway over Istio** — canary traffic splitting without sidecar overhead
- **KServe evaluated, deferred** — controller installed and running; storage-credential
  propagation exceeded the time-box for a single-model platform. The hand-built MinIO
  init-container pattern is functionally KServe's ModelCar.
- **Hybrid GPU strategy** — CPU control plane on GKE, GPU rented per-benchmark
- **Spot → on-demand** — root-caused via autoscaler visibility logs, not assumed

---

## Engineering Highlights

Debugged through real production-style failures, each documented with
symptom → root cause → fix → lesson in [FAILURES.md](./FAILURES.md):

- Autoscaler scheduling deadlock (taint vs. predicate simulation)
- AVX-512 SIGILL — CPU-microarchitecture mismatch on e2 nodes
- HuggingFace CDN failure → pivoted to in-cluster MinIO model registry
- KV-cache OOMKill — serving memory is cache + runtime, not just weights
- Silent init-container failure masked by a misleading success log

---

## Roadmap

- [ ] Quantization sweep: FP16 vs AWQ vs GPTQ on L4 (throughput, TTFT, cost/token)
- [ ] Prefix-caching hit-rate instrumentation
- [ ] KEDA autoscaling + cold-start analysis
- [ ] HAMi GPU virtualization demo (sliced L4)
- [ ] OTel + Jaeger distributed tracing
- [ ] Canary rollout demo via Envoy

---

## Repository Structure

```
terraform/        GKE cluster, VPC, node pools (IaC)
argocd/           App-of-apps GitOps definitions
platform/         Component configs (vllm, litellm, envoy, minio, monitoring)
benchmarks/       k6 load tests + results
docs/             Architecture, DECISIONS, FAILURES, SLOs
```

## Quick Start

```bash
cd terraform && terraform init && terraform apply        # provision GKE
kubectl apply -f argocd/bootstrap/root-app.yaml          # bootstrap GitOps
# everything else syncs from Git via ArgoCD
```

---

*Built by [Devam Thacker](https://www.linkedin.com/in/devamthacker) — AI Infrastructure & MLOps.*
