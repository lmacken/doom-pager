# Prefetch Analysis for WiFi Pineapple Pager

## Summary

**Manual render loop prefetch is HARMFUL** - proven 35% slower in real-world benchmarks.

## Benchmark Results (Real Framebuffer)

| Metric | No Prefetch | Manual Prefetch | Difference |
|--------|-------------|-----------------|------------|
| Render (CPU) | 3574 µs | 4820 µs | **-35% slower** |
| Write (SPI) | 2035 µs | 2175 µs | -7% slower |
| Total | 5609 µs | 6996 µs | **-25% slower** |
| FPS Potential | 178 FPS | 143 FPS | -25% |

## Why Manual Prefetch Hurts

The render loop uses **lookup tables** for 90° rotation + scaling:

```c
// Prefetch target:
__builtin_prefetch(&srcBuf[yLookup[x+16] * DOOM_W + srcX], 0, 0);
```

The problem: `yLookup[x+16]` is **NOT sequential**!

```
yLookup[0]  = 0 * 200 / 222 = 0
yLookup[16] = 16 * 200 / 222 = 14
yLookup[32] = 32 * 200 / 222 = 28
```

When `x=0`, we prefetch `srcBuf[14*320 + srcX]` = `srcBuf[4480 + srcX]`
But we actually need `srcBuf[0*320 + srcX]` = `srcBuf[srcX]`!

### Cache Pollution

- MIPS 24KEc has 32KB L1 D-cache
- I_VideoBuffer is 64KB (doesn't fit!)
- Wrong prefetch evicts useful cache lines
- Result: MORE cache misses, not fewer

## Prefetch Variants Comparison

| Variant | Pref Instructions | Performance |
|---------|-------------------|-------------|
| No prefetch | 1 | **FASTEST** |
| GCC -fprefetch-loop-arrays | 150 | Marginal benefit |
| Manual render prefetch | 5 | **35% SLOWER** |

## Recommendation

1. **Disable manual render prefetch** (default now)
2. **Consider GCC auto-prefetch** for game logic loops
3. **Measure before optimizing** - intuition was wrong!

## When Prefetch DOES Help

Prefetch works for:
- Sequential memory access (arrays scanned linearly)
- Predictable patterns (stride access)
- Data larger than cache but accessed predictably

Prefetch HURTS for:
- Random/lookup-table access patterns
- Small data that already fits in cache
- When prefetch distance is wrong

## Files Changed

- `doomgeneric_linuxvt.c`: Manual prefetch disabled by default
- `Makefile.mipsel`: Use `MANUAL_PREFETCH=1` to re-enable for testing
