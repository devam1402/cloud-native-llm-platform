# Quantization Benchmark — Qwen2.5-7B on NVIDIA L4

| Format | Source | GPU Memory (MiB) | Tok/s | p95(ms) | Req/s | Err% |
|--------|--------|-----------------:|------:|---------:|------:|-----:|
| AWQ | HuggingFace official | 20062 | 9.090114 | 6.49s | 9.090114 | 0.00 |
| FP16 | original | 20498 | 4.597706 | 10.07s | 4.597706 | 0.00 |
| FP8 | self (LLM Compressor) | 20532 | 7.090975 | 6.68s | 7.090975 | 0.00 |
| W4A16 | self (GPTQ) | 20600 | 9.348845 | 6.21s | 9.348845 | 0.00 |
| W4A16+FP8kv | self + cache quant | 21070 | 9.592308 | 5.97s | 9.592308 | 0.00 |

## Quality Check

- **awq** ✅ `The capital of France is Paris.`
- **fp16** ✅ `The capital of France is Paris.`
- **fp8** ✅ `The capital of France is Paris.`
- **w4a16** ✅ `Paris.`
- **w4a16_fp8kv** ✅ `The capital of France is Paris.`

## Recommendation

- Lowest GPU memory: **awq** (20062 MiB)
