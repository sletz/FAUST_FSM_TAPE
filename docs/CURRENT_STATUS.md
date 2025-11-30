# FAUST JA Hysteresis Library — Current Status

**Last updated**: 2025-11-30
**Collaborators**: Thomas Mandolini (OmegaDSP), GRAME (Stéphane Letz)

---

## Project Goal

Create a reusable **FAUST library (`jahysteresis.lib`)** for Jiles-Atherton magnetic hysteresis with phase-locked bias oscillator, suitable for tape saturation simulation.

**Target**: Mastering-grade quality at production-viable CPU cost.

**Library prefix**: `jah` (e.g., `jah.tape_channel_ui`)

---

## Current State

### What Works

| Component | Status | Notes |
|-----------|--------|-------|
| JA physics model | Complete | Ms=320, a=720, k=280, c=0.18, α=0.015 |
| Phase-locked bias oscillator | Complete | Fixed cycles/sample, sample-rate invariant |
| 2D LUT optimization | Complete | 1 real substep + LUT lookup |
| 10 bias modes (K28-K2101) | Complete | LoFi to beyond-physical range (all half-integer cycles) |
| FAUST prototype (ba.if) | Complete | `dev/ja_streaming_bias_proto.dsp` |
| FAUST prototype (ondemand) | Complete | `test/ja_streaming_bias_proto_od.dsp` |
| FAUST library | In Progress | `jahysteresis.lib` (contribution-ready) |
| C++ reference | Complete | `JAHysteresisScheduler` with ~11% CPU |

### Performance (M4 Max, Ableton Live 12.3, AU)

| Implementation | CPU @ K60 | Notes |
|----------------|-----------|-------|
| FAUST (original, 66 substeps) | ~24% | Sequential dependency bottleneck |
| C++ scheduler | ~11% | Uses fractional substep accumulation |
| FAUST + LUT | ~1% | 20x+ improvement |

### Achieved Breakthrough

**Key insight**: Only substep 0 has cross-sample dependency. Substeps 1..N-1 are deterministic given (M1, H_audio).

**Solution**: Precompute 2D LUT mapping `(M_in, H_audio) → (M_end, sumM_rest)` for the deterministic portion.

**Result**: Collapsed 66 JA physics evaluations to 1 + cheap bilinear interpolation.

---

## Open Problems

### 1. Parallel Computation Overhead (Priority: High) — SOLVED

**Problem**: FAUST `ba.if` is a signal selector, not a conditional branch. All 10 mode loops are computed every sample; `ba.if` just picks the output.

**Solution**: The **Ondemand primitive** (Yann Orlarey, IFC 24) is now working! It enables true conditional block execution where only the selected mode computes.

**Implementation**: `faust/test/ja_streaming_bias_proto_od.dsp` uses `ondemand` with a dev fork in `tools/faust-ondemand/`.

```faust
// Old: 10 parallel computations (ba.if)
ba.if(mode < 0.5, loopK28, ba.if(mode < 1.5, loopK45, ...))

// New: Only active mode computes (ondemand)
sum(i, 10, clk(i) * (clk(i) : ondemand(loop(i, H_in))))
```

**Status**: Prototype builds and runs as AU plugin. CPU testing pending.

### 2. Harmonic Imprint Research (Priority: High) — SOLVED

**Solution**: All modes now use **half-integer cycles + odd substeps**. This ensures opposite bias polarity between adjacent samples, introducing even harmonics for warmer, more musical tone.

| Mode | Cycles | Substeps | Character |
|------|--------|----------|-----------|
| K28 | 1.5 | 27 | Maximum grit |
| K45 | 2.5 | 45 | Crunchy, lo-fi |
| K63 | 3.5 | 63 | Classic tape |
| K99 | 4.5 | 99 | Smooth warmth |
| K121 | 5.5 | 121 | Standard (default) |
| K187 | 8.5 | 187 | High quality |
| K253 | 11.5 | 253 | Very detailed |
| K495 | 22.5 | 495 | Ultra detailed |
| K1045 | 47.5 | 1045 | Extreme |
| K2101 | 95.5 | 2101 | Beyond physical |

**Key insight**: Lower substep counts introduce inter-sample "aliasing" that manifests as characteristic harmonics — a feature for lo-fi modes, minimized in HQ modes.

### 3. LUT Parameter Flexibility (Priority: Medium)

**Current limitation**: LUTs are precomputed for fixed bias parameters:
- `bias_level = 0.41`
- `bias_scale = 11.0`

**Problem**: Changing these parameters at runtime would require different LUTs.

**Options**:
1. Multiple LUT banks for discrete parameter presets
2. 3D or 4D LUT with parameter dimensions (memory-heavy)
3. Runtime LUT regeneration (background thread, crossfade)
4. Accept fixed bias as "tape formulation" preset

### 4. Variable Iteration Pattern (Priority: Low)

**C++ reference behavior**: Fractional substep accumulation causes step count to vary (e.g., 35-37 for K60) for better phase continuity.

**FAUST limitation**: Fixed unrolled chains require compile-time constant iteration count.

**Impact**: Subtle high-frequency response differences between FAUST and C++.

**Potential FAUST pattern**: Unroll to max count, gate inactive steps:
```faust
ba.if(step_idx < steps_this_sample, computeStep, passThrough)
```

**Note**: With LUT optimization, this becomes less critical since only substep 0 is computed in real-time.

---

## Technical Discoveries

### Why External LUT Generation is Required

Investigated FAUST's `ba.tabulate` and `ba.tabulate_chebychev` functions for potential init-time table computation. 

**Finding**: These functions **cannot** be used for JA hysteresis LUTs.

**Reason**: `ba.tabulate` can only tabulate **pure FAUST functions** — functions with no state, no feedback, no iteration. It evaluates `function(x)` for various x values at init time.

JA physics requires:
- Iterative Newton-Raphson solving (feedback loop)
- 66 sequential substeps, each depending on the previous
- State variables (M_prev carrying across substeps)

This cannot be expressed as a pure function `y = f(x)` that FAUST can evaluate at init time.

**Conclusion**: External Python LUT generation is the correct architecture. The Python computation is a one-time offline cost; the resulting FAUST code has zero table-computation overhead — just memory reads via `rdtable`.

**What `ba.tabulate` IS useful for**:
- Simple functions: `sin(x)`, `tanh(x)`, polynomial approximations
- Any stateless computation expressible as `y = f(x)`
- Could potentially be used for the bilinear interpolation coefficients if needed

### FAUST Optimization Resources (from Stéphane Letz)

Key documentation reviewed:
- [Init-time computation](https://faustdoc.grame.fr/manual/optimizing/#computations-done-at-init-time)
- [ba.tabulate functions](https://faustlibraries.grame.fr/libs/basics/#batabulate)
- [General optimization guide](https://faustdoc.grame.fr/manual/optimizing/)

**Note**: Same LUT optimization approach could be applied to the C++ version for even lower CPU usage.

---

## Challenges to Overcome

### Technical

1. **FAUST `rdtable` constraints**
   - 1D only (solved with flattened 2D indexing)
   - Compile-time table definition (solved with external generation)
   - All tables loaded into memory regardless of mode selection

2. **State accumulation sensitivity**
   - JA hysteresis is highly sensitive to floating-point precision
   - `float` precision degraded quality; `double` required
   - Polynomial `tanh` approximations changed tone

3. **Memory footprint**
   - 10 modes × 8385 values × 2 tables × 8 bytes = ~1.3 MB
   - Acceptable for plugin, may need reduction for embedded

### Architectural

1. **Library API design**
   - What parameters should be exposed vs. fixed?
   - How to handle mode selection without parallel overhead?
   - Should physics parameters (Ms, a, k, c, α) be runtime-adjustable?

2. **Integration with parent FSM_TAPE project**
   - This repo contains extracted JA hysteresis only
   - Need clean interface for reintegration

---

## Research Directions

### Bias Waveform Variations (Future)

Current: Pure sine bias oscillator.

**Potential exploration**:
- Asymmetric bias (different positive/negative excursions)
- Harmonic-rich bias (triangle, modified sine)
- These would require new LUT sets but could expand tonal palette

---

## File Structure

```
FAUST_FSM_TAPE/
├── faust/
│   ├── jahysteresis.lib              # Contribution-ready FAUST library (jah prefix)
│   ├── ja_lut_k*.lib                 # 10 mode-specific LUT libraries (K28-K2101)
│   ├── rebuild_faust.sh              # Build script preserving plugin IDs
│   ├── dev/
│   │   └── ja_streaming_bias_proto.dsp   # Working prototype (reference)
│   └── examples/
│       └── jah_tape_demo.dsp         # Demo importing jahysteresis.lib
├── juce_plugin/
│   └── Source/
│       ├── JAHysteresisScheduler.h   # C++ reference implementation
│       └── JAHysteresisScheduler.cpp
├── scripts/
│   └── generate_ja_lut.py            # LUT generator
└── docs/
    ├── CURRENT_STATUS.md             # This file
    ├── LUT_RESTRUCTURE_PLAN.md       # Unified LUT proposal
    ├── JA_LUT_IMPLEMENTATION_PLAN.md # Original LUT design
    └── JA_Hysteresis_Optimization_Summary.md
```

**Note**: `jahysteresis.lib` is the library-ready version for GRAME contribution.
`dev/ja_streaming_bias_proto.dsp` is the working prototype kept as reference.

---

## Next Steps

### Immediate (Code)

1. Implement unified LUT structure (`LUT_RESTRUCTURE_PLAN.md`)
2. Benchmark CPU reduction from eliminating parallel computation
3. Validate sound quality against per-mode LUT version

### Research

1. Conduct harmonic imprint analysis for all 10 modes
2. Identify musically distinct anchor points
3. Determine if mode interpolation is viable

### Documentation

1. Define `jahysteresis.lib` public API
2. Write usage examples for GRAME review
3. Document integration path back to FSM_TAPE

### IFC 2026 Preparation

Invited by Stéphane Letz to present at **International Faust Conference 2026**:
- **Date**: June 28-29, 2026
- **Location**: Cannes, France
- **Topic**: AI-assisted DSP development workflow, JA hysteresis optimization journey

---

## Questions for GRAME

1. Any recommendations for managing multiple LUT variants (mode × parameter combinations)?
2. ~~Timeline for the **Ondemand primitive**?~~ — Working! Dev fork in `tools/faust-ondemand/`
3. Best practices for contributing optimized libraries to faustlibraries?

---

## Commit History Summary

| Commit | Description |
|--------|-------------|
| `946d4e2` | Expand to 10 bias modes (K28-K1920) with corrected LUTs |
| `55474e8` | 2D LUT optimization - 20x+ CPU reduction |
| `652ae5a` | Add FSM paper and phase-locked bias research |
| `c361a6d` | Simplify FAUST code using `seq(i,N,exp)` form |
| `76a5087` | Initial JA hysteresis FAUST/C++ comparison |

---

## Contact

- **Thomas Mandolini** — thomas.mand0369@gmail.com
- **Repository** — https://github.com/Mando-369/FAUST_FSM_TAPE
