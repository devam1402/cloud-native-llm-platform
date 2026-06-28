# Quantization Sweep — Predictions (stated before running)

## Hardware
NVIDIA L4, 24GB, Ada SM 8.9, ~300 GB/s bandwidth, Jarvislabs $0.44/hr

## Predictions

### Memory footprint
| Variant | Predicted weights |
|---------|-------------------|
| FP16    | ~14 GB |
| FP8     | ~7 GB  |
| W4A16   | ~4.5 GB |
| AWQ     | ~4.5 GB |

### Throughput
4-bit variants ~2-2.5× FP16 (decode is memory-bandwidth bound).
FP8 ~1.5×.

### Quality
Predicted: FP16 ≥ FP8 ≥ AWQ ≥ W4A16. FP8 near-lossless.

### The gap I expect
Theoretical 4× bandwidth speedup will EXCEED observed ~2.3× throughput
because prefill is compute-bound. The gap quantifies prefill overhead.
