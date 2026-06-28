# Two LLMs. One GPU. Hard Isolation.

Most setups give each model its own GPU. I made two vLLM workloads share a
single NVIDIA L4 — each locked to its own 11GB slice, neither able to touch
the other's memory. Here's the proof.

## The money shot

`nvidia-smi` on the host, both models live:
GPU 0: NVIDIA L4 — 15110MiB / 23034MiB

PID 22945 (vllm-a): 7536MiB   ← slice A

PID 23038 (vllm-b): 7536MiB   ← slice B

Two processes. One physical card. On a normal Kubernetes cluster, the second
pod would sit `Pending` forever — there's only one GPU. HAMi made them coexist.

## Both actually serving (not just scheduled)
model-a ← "Hello from slice A"  → completion ✅

model-b ← "Hello from slice B"  → completion ✅

Scheduling two pods is easy. Getting two isolated models to *both serve
traffic* from one GPU, with enforced memory limits, is the real test. They passed.

## How it was built

| Layer | What |
|-------|------|
| Hardware | 1× NVIDIA L4 24GB (rented, Jarvislabs) |
| Cluster | Single-node kubeadm, built from scratch |
| GPU stack | NVIDIA GPU Operator (default device plugin disabled) |
| Virtualization | HAMi v2.9.0 — device plugin + scheduler + CUDA hook |
| Workloads | 2× vLLM, each: `nvidia.com/gpumem: 11000`, `gpucores: 50` |

## Why HAMi and not MIG

The L4 doesn't support NVIDIA MIG — there's no hardware partitioning on this
card. HAMi solves it in software: its `libvgpu.so` hooks every CUDA call inside
the container and enforces the memory ceiling. Each pod *thinks* it has 11GB and
genuinely cannot exceed it. That's the entire point — **GPU sharing on hardware
that NVIDIA says can't be partitioned.**

## What I scoped out (and why)

This demo proves HAMi's NVIDIA memory + core slicing with hard isolation on a
single node. HAMi also does heterogeneous accelerators (AMD/Ascend/Hygon),
topology-aware multi-GPU scheduling, and Kueue queue integration — all out of
scope for one card on one node. But every one of those features is built on the
exact slicing mechanism demonstrated here. Get this right and the rest scales up.
