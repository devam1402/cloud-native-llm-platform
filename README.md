# Cloud-Native LLM Inference Platform

A production-style, GitOps-managed Kubernetes platform for serving LLMs on GKE —
self-service deployment, cost-optimized GPU usage, full observability, and
published load-test baselines.


![Architecture](./docs/architecture/architecture.png)

---

## Live Platform

- Serving on a public IP: **Envoy Gateway → LiteLLM → vLLM**
- Every component deployed via **ArgoCD GitOps** (zero manual kubectl after bootstrap)
- Models served from an **in-cluster MinIO registry** (no external CDN at runtime)

---

## What's Built

Three differentiated capabilities, each measured and evidenced — not just deployed.

### 1. Quantization Sweep — self-quantized, benchmarked

Self-quantized Qwen2.5-7B with **LLM Compressor** (not downloaded pre-made), then
benchmarked five formats on an L4 under identical k6 load. Predictions were stated
*before* running — see [benchmarks/quantization/PREDICTIONS.md](./benchmarks/quantization/PREDICTIONS.md).

| Format | Source | Tok/s | p95 | vs FP16 | Quality |
| ------ | ------ | ----: | --: | ------: | ------- |
| FP16 | original | 4.6 | 10.1s | baseline | pass |
| FP8 | self (LLM Compressor) | 7.1 | 6.7s | **1.5x** | pass |
| W4A16 | self (GPTQ) | 9.3 | 6.2s | **2.0x** | pass |
| W4A16 + FP8 KV | self + cache quant | 9.6 | 6.0s | **2.1x** | pass |
| AWQ | HuggingFace official | 9.1 | 6.5s | **2.0x** | pass |

All variants: 0% errors under 100 concurrent users, no quality regression.
The observed 2x (vs a theoretical 4x for 4-bit) is explained by the prefill tax —
full analysis in [benchmarks/analysis/results.md](./benchmarks/analysis/results.md).

### 2. HAMi GPU Virtualization — two models, one GPU

Two vLLM workloads sharing a single L4, each locked to an 11GB slice with hard
isolation. The L4 doesn't support MIG, so this is software slicing via HAMi's
CUDA-API hook. Evidence (nvidia-smi showing two processes on one card) in
[hami-demo/EVIDENCE.md](./hami-demo/EVIDENCE.md).

### 3. KEDA Autoscaling — queue-depth, not CPU

vLLM autoscaled on `vllm:num_requests_waiting` (via Prometheus), not CPU — because
CPU is a poor proxy for GPU-bound LLM load. Under load, KEDA correctly scaled to max
(observed `155/1` queue depth, 4 replicas requested). Only 1 scheduled — surfacing
the **KEDA-vs-cluster-autoscaler boundary** (KEDA scales pods; node capacity gates
scheduling). Analysis in [benchmarks/analysis/cold-start.md](./benchmarks/analysis/cold-start.md).

---

## Baseline (k6 load test)

CPU path-validation baseline — Envoy → LiteLLM → vLLM, opt-125m on n2-standard-4:

| Metric | Value |
| ----------- | ---------------------------------- |
| Requests | 912 |
| Error rate | **0.0%** under 25 concurrent users |
| p50 latency | 3,474 ms |
| p95 latency | 4,232 ms |
| Throughput | 11 tokens/sec |

*Latency is CPU-bound (opt-125m). GPU quantization benchmarks compare against this baseline.*

---

## Stack

| Layer | Tool | Why |
| -------------- | -------------------- | ---------------------------------------- |
| Infrastructure | Terraform + GKE | IaC, remote state, least-privilege IAM |
| Delivery | ArgoCD (app-of-apps) | GitOps — Git is the source of truth |
| Serving | vLLM | OpenAI-compatible LLM inference |
| Gateway | LiteLLM | Auth, cost tracking, multi-model routing |
| Ingress | Envoy Gateway | Kubernetes Gateway API, canary-capable |
| Autoscaling | KEDA | Queue-depth scaling on Prometheus metrics |
| GPU sharing | HAMi | Memory-sliced GPU virtualization (non-MIG) |
| Quantization | LLM Compressor | Self-quantized FP8 / W4A16 |
| Registry | MinIO | In-cluster model + benchmark store |
| Observability | Prometheus + Grafana | Metrics, dashboards, SLOs |
| Load testing | k6 | Reproducible baselines, CI-gateable |

**Deliberately cut** (see [docs/DECISIONS.md](./docs/DECISIONS.md)): Istio (Envoy
suffices without service-mesh tax), Kubeflow/Kueue/Argo-Workflows (training/batch
scope — this is inference-only), Knative (RawDeployment avoids cold-start variance),
LMCache distributed features (require multi-GPU/multi-node).

---

## Architecture Decisions

Documented as ADRs in [docs/DECISIONS.md](./docs/DECISIONS.md):

- **Envoy Gateway over Istio** — canary traffic splitting without sidecar overhead
- **KServe evaluated, deferred** — controller installed and running; storage-credential
propagation exceeded the time-box for a single-model platform. The hand-built MinIO
init-container pattern is functionally KServe's ModelCar.
- **Hybrid GPU strategy** — CPU control plane on GKE, GPU rented per-benchmark
- **Spot to on-demand** — root-caused via autoscaler visibility logs, not assumed

---

## Engineering Highlights

Debugged through real production-style failures, each documented with
symptom, root cause, fix, and lesson in [FAILURES.md](./FAILURES.md):

- Autoscaler scheduling deadlock (taint vs. predicate simulation)
- AVX-512 SIGILL — CPU-microarchitecture mismatch on e2 nodes
- HuggingFace CDN failure, pivoted to in-cluster MinIO model registry
- KV-cache OOMKill — serving memory is cache + runtime, not just weights
- Silent init-container failure masked by a misleading success log
- `.venv` committed — out-of-bounds symlink stalled the entire ArgoCD root sync
- KEDA operator CrashLoopBackOff — CRDs not applied before the controller started
- ServiceMonitor silently not scraping — service had no labels to select on
- LMCache image entrypoint silently filtered CLI args — caught via `ps aux` vs pod spec

---


## Repository Structure

```
terraform/        GKE cluster, VPC, node pools (IaC)
argocd/           App-of-apps GitOps definitions
platform/         Component configs (vllm, litellm, envoy, minio, monitoring, keda)
benchmarks/       k6 load tests, quantization sweep, analysis
hami-demo/        GPU virtualization evidence
docs/             Architecture, DECISIONS, FAILURES, SLOs
```

## Quick Start

```
cd terraform && terraform init && terraform apply        # provision GKE
kubectl apply -f argocd/bootstrap/root-app.yaml          # bootstrap GitOps
# everything else syncs from Git via ArgoCD
```

---

*Built by [Devam Thacker](https://www.linkedin.com/in/devamthacker) — AI Infrastructure & MLOps.*
