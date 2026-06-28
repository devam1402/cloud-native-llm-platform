#!/usr/bin/env python3

import csv
import json
import re
from pathlib import Path

# -----------------------------
# Configuration
# -----------------------------

ROOT = Path("benchmarks/results/l4-2026-06-28/results")
OUT = ROOT.parent

SOURCE_MAP = {
    "fp16": ("FP16", "original"),
    "fp8": ("FP8", "self (LLM Compressor)"),
    "w4a16": ("W4A16", "self (GPTQ)"),
    "w4a16_fp8kv": ("W4A16+FP8kv", "self + cache quant"),
    "awq": ("AWQ", "HuggingFace official"),
}

records = []

# -----------------------------
# Parse every benchmark
# -----------------------------

for gpu_file in sorted(ROOT.glob("*-gpu.txt")):

    method = gpu_file.stem.replace("-gpu", "")

    record = {
        "method": method,
        "gpu_memory_mib": None,
        "quality": "",
        "tokens_per_sec": "?",
        "p95_ms": "?",
        "req_per_sec": "?",
        "error_rate": "?",
    }

    # -------------------------
    # GPU
    # -------------------------

    gpu_text = gpu_file.read_text()

    m = re.search(r'(\d+)\s+MiB,\s+(\d+)\s+MiB', gpu_text)

    if m:
        record["gpu_memory_mib"] = int(m.group(1))

    # -------------------------
    # Quality
    # -------------------------

    qfile = ROOT / f"{method}-quality.json"

    if qfile.exists():

        data = json.loads(qfile.read_text())

        record["quality"] = (
            data["choices"][0]["text"].strip()
        )

    # -------------------------
    # k6
    # -------------------------

    logfile = ROOT / f"{method}-k6.log"

    if logfile.exists():

        log = logfile.read_text()

        m = re.search(r'http_reqs.*?([\d\.]+)\/s', log)

        if m:
            record["req_per_sec"] = m.group(1)

        m = re.search(r'p\(95\)=([\d\.]+)(ms|s)', log)

        if m:
            record["p95_ms"] = m.group(1) + m.group(2)

        m = re.search(r'http_req_failed.*?([\d\.]+)%', log)

        if m:
            record["error_rate"] = m.group(1)

        m = re.search(r'iterations.*?([\d\.]+)\/s', log)

        if m:
            record["tokens_per_sec"] = m.group(1)

    records.append(record)

# -----------------------------
# Sort
# -----------------------------

records.sort(
    key=lambda x: x["gpu_memory_mib"]
)

# -----------------------------
# CSV
# -----------------------------

with open(
    OUT / "summary.csv",
    "w",
    newline=""
) as f:

    writer = csv.DictWriter(
        f,
        fieldnames=records[0].keys()
    )

    writer.writeheader()

    writer.writerows(records)

# -----------------------------
# JSON
# -----------------------------

with open(
    OUT / "summary.json",
    "w"
) as f:

    json.dump(records, f, indent=2)

# -----------------------------
# Markdown Report
# -----------------------------

with open(
    OUT / "BENCHMARK.md",
    "w"
) as f:

    f.write("# Quantization Benchmark — Qwen2.5-7B on NVIDIA L4\n\n")

    f.write(
        "| Format | Source | GPU Memory (MiB) | Tok/s | p95(ms) | Req/s | Err% |\n"
    )

    f.write(
        "|--------|--------|-----------------:|------:|---------:|------:|-----:|\n"
    )

    for r in records:

        fmt, src = SOURCE_MAP[r["method"]]

        f.write(
            f"| {fmt} "
            f"| {src} "
            f"| {r['gpu_memory_mib']} "
            f"| {r['tokens_per_sec']} "
            f"| {r['p95_ms']} "
            f"| {r['req_per_sec']} "
            f"| {r['error_rate']} |\n"
        )

    f.write("\n")

    f.write("## Quality Check\n\n")

    for r in records:

        status = "✅"

        if "Paris" not in r["quality"]:
            status = "⚠️"

        f.write(
            f"- **{r['method']}** {status} `{r['quality']}`\n"
        )

    best = min(
        records,
        key=lambda x: x["gpu_memory_mib"]
    )

    f.write("\n## Recommendation\n\n")

    f.write(
        f"- Lowest GPU memory: **{best['method']}** ({best['gpu_memory_mib']} MiB)\n"
    )

print()

print("Generated:")

print(OUT / "summary1.csv")
print(OUT / "summary1.json")
print(OUT / "BENCHMARK1.md")