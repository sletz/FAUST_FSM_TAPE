# CLAUDE.md

## Project Overview

This is a **GRAME collaboration repository** containing Jiles-Atherton magnetic hysteresis implementations for tape saturation simulation. The goal is to get GRAME/FAUST team help optimizing the algorithm and potentially creating a `ja.lib` library.

**Parent project**: FSM_TAPE (full plugin with limiter, EQ, clipper)
**This repo**: Extracted minimal JA hysteresis for comparison and optimization

## Two Implementations (Must Match!)

### 1. FAUST Version (`faust/ja_streaming_bias_proto.dsp`)
- Pure FAUST implementation with sin/cos recurrence optimization
- Unrolled substep loops (FAUST limitation)
- Build: `faust2juce -osc ja_streaming_bias_proto.dsp`

### 2. C++ Version (`juce_plugin/`)
- JUCE plugin wrapping JAHysteresisScheduler
- Direct sin() calls per substep
- Build: Clone JUCE, then `cmake -S . -B build -G Xcode && cmake --build build --config Release`

## Critical: Keep Implementations Matched

Both versions must use identical:
- **Physics params**: Ms=320, a=720, k=280, c=0.18, α=0.015
- **Substep counts**: K32=36, K48=54, K60=66 (Normal quality)
- **fast_tanh**: `t * (27 + x²) / (27 + 9x²)`
- **DC blocker**: 10 Hz highpass

If you change one, change the other!

## Mode/Substep Matrix

| Mode | Bias Cycles | Substeps | Points/Cycle |
|------|-------------|----------|--------------|
| K32 | 2 cycles/sample | 36 | 18 |
| K48 | 3 cycles/sample | 54 | 18 |
| K60 | 3 cycles/sample | 66 | 22 |

## File Structure

```
FAUST_FSM_TAPE/
├── faust/
│   └── ja_streaming_bias_proto.dsp   # Main FAUST prototype
├── juce_plugin/
│   ├── CMakeLists.txt
│   ├── Source/
│   │   ├── PluginProcessor.h/cpp     # Minimal JUCE wrapper
│   │   └── JAHysteresisScheduler.h/cpp
│   └── JUCE/                         # Clone here (gitignored)
├── cpp_reference/                    # Original C++ files (reference only)
├── context/                          # Full plugin DSP files (context)
└── docs/                             # Physics documentation
```

## Common Tasks

### Test FAUST syntax
```bash
faust -double ja_streaming_bias_proto.dsp  # Just check compilation
```

### Build FAUST plugin
```bash
cd faust
faust2juce -osc ja_streaming_bias_proto.dsp
cd ja_streaming_bias_proto
cmake -S . -B build -G Xcode
cmake --build build --config Release
```

### Build C++ plugin
```bash
cd juce_plugin
git clone https://github.com/juce-framework/JUCE.git  # First time only
cmake -S . -B build -G Xcode
cmake --build build --config Release
```

## Parameters (Both Versions)

| Parameter | Range | Default |
|-----------|-------|---------|
| Input Gain | -24 to +24 dB | 0 dB |
| Output Gain | -24 to +48 dB | 34 dB |
| Drive | -18 to +18 dB | -10 dB |
| Bias Level | 0.0 - 1.0 | 0.4 |
| Bias Scale | 1.0 - 100.0 | 11.0 |
| Bias Resolution | K32/K48/K60 | K48 |
| Bias Ratio | 0.98 - 1.02 | 1.0 |
| Mix | 0.0 - 1.0 | 1.0 |

## Goals for GRAME

1. Optimize unrolled loop pattern in FAUST
2. Potential `ja.lib` library
3. Improve sin/cos recurrence or suggest alternatives
4. Reduce generated C++ code size

## Notes

- C++ version hardcoded to "Normal" quality (no Eco/Ultra selector)
- FAUST uses sin/cos recurrence, C++ uses direct sin() - compare CPU!
- Both use phase-locked bias oscillator (SR-invariant)
- No limiter, EQ, or clipper - pure JA comparison only
