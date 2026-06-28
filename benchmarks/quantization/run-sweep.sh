#!/usr/bin/env bash
set -uo pipefail
mkdir -p results

run() {
  local NAME=$1 MODEL=$2 EXTRA="${3:-}"
  echo "═══ $NAME ═══"
  vllm serve "$MODEL" --served-model-name qwen2.5-7b --port 8000 \
    --max-model-len 4096 --gpu-memory-utilization 0.90 \
    --enable-prefix-caching --disable-log-requests $EXTRA \
    > "results/${NAME}-serve.log" 2>&1 &
  local PID=$!
  for i in $(seq 1 40); do curl -sf localhost:8000/health >/dev/null 2>&1 && break; sleep 10; done
  curl -sf localhost:8000/health >/dev/null 2>&1 || { echo "FAILED $NAME"; kill $PID 2>/dev/null; sleep 5; return; }
  nvidia-smi --query-gpu=memory.used,memory.total --format=csv > "results/${NAME}-gpu.txt"
  nvidia-smi >> "results/${NAME}-gpu.txt"
  k6 run sweep.js 2>&1 | tee "results/${NAME}-k6.log"
  curl -s localhost:8000/v1/completions -H "Content-Type: application/json" \
    -d '{"model":"qwen2.5-7b","prompt":"What is the capital of France? One sentence.","max_tokens":30,"temperature":0}' \
    > "results/${NAME}-quality.json"
  kill $PID 2>/dev/null; sleep 15
}

run "fp16"  "Qwen/Qwen2.5-7B-Instruct"
run "fp8"   "./qwen2.5-7b-FP8-Dynamic"
run "w4a16" "./qwen2.5-7b-W4A16"
run "w4a16_fp8kv" "./qwen2.5-7b-W4A16" "--kv-cache-dtype fp8"
run "awq"   "Qwen/Qwen2.5-7B-Instruct-AWQ"

tar -czf ~/quant-results.tar.gz results/
echo "DONE. Download quant-results.tar.gz, then TERMINATE."
ls -la results/
