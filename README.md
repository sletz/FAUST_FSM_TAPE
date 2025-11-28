# FAUST_FSM_TAPE - Jiles-Atherton Magnetic Hysteresis for GRAME

## Overview

This repository contains a FAUST implementation of the **Jiles-Atherton (JA) magnetic hysteresis model** with a **phase-locked, sample-rate-driven bias oscillator**. The goal is to simulate authentic analog tape saturation behavior for audio processing.

**Author**: Thomas Mandolini / OmegaDSP
**Contact**: [your email here]

## What We're Looking For

We're hoping the GRAME/FAUST team can help with:

1. **Performance optimization** of the JA hysteresis loop (currently uses unrolled substep chains)
2. **Potential `ja.lib` library** - a reusable Jiles-Atherton hysteresis module for FAUST
3. **Sin/cos recurrence optimization** - the prototype uses a recurrence relation for efficient bias oscillator
4. **Feedback/suggestions** on idiomatic FAUST patterns for this type of iterative physics simulation

## The Algorithm

### Jiles-Atherton Hysteresis Model

The JA model simulates magnetic hysteresis using 5 physics parameters:

| Parameter | Symbol | Default | Description |
|-----------|--------|---------|-------------|
| Saturation Magnetization | Ms | 320 | Maximum magnetization |
| Domain Density | a | 720 | Anhysteretic curve shape |
| Pinning Coefficient | k | 280 | Coercivity (loop width) |
| Reversibility | c | 0.18 | Reversible/irreversible ratio |
| Coupling | α | 0.015 | Mean field coupling |

The core equation computes `dM/dH` (change in magnetization per change in field):

```
dM/dH = (c * dMan/dH + (Man - M) / pin) / (1 - c * α * dMan/dH)
```

Where `Man` is the anhysteretic magnetization computed via `tanh()`.

### Phase-Locked Bias Oscillator

Real tape machines use a high-frequency bias signal (~100kHz) to linearize the magnetic recording. We simulate this with a **phase-locked oscillator** that runs a fixed number of bias cycles per audio sample:

| Mode | Bias Cycles | Substeps | Points/Cycle |
|------|-------------|----------|--------------|
| K32 | 2 cycles/sample | 36 | 18 |
| K48 | 3 cycles/sample | 54 | 18 |
| K60 | 3 cycles/sample | 66 | 22 |

This approach is **sample-rate invariant** - the bias phase coverage is identical whether running at 44.1kHz or 192kHz.

### Midpoint Integration

Each substep samples the bias at its midpoint for numerical stability:

```faust
sin(phi_start + (i + 0.5) / K * dphi)
```

The final magnetization is averaged across all substeps, effectively removing the bias frequency from the output while retaining its linearizing effect on the hysteresis.

## Repository Structure

```
FAUST_FSM_TAPE/
├── README.md                         # This file
├── faust/
│   └── ja_streaming_bias_proto.dsp   # Main FAUST prototype (K32/K48/K60)
├── juce_plugin/                      # Minimal C++ JUCE plugin for A/B testing
│   ├── CMakeLists.txt
│   ├── README.md
│   └── Source/
│       ├── PluginProcessor.h/cpp
│       └── JAHysteresisScheduler.h/cpp
├── cpp_reference/
│   ├── JAHysteresisScheduler.h       # C++ header
│   └── JAHysteresisScheduler.cpp     # C++ implementation
├── context/
│   ├── FSM_Tape_Pre.dsp              # Pre-processing (limiter, EQ, drive)
│   └── FSM_Tape_Post.dsp             # Post-processing (DC block, output)
└── docs/
    ├── FSM-PHL-SRD-BIAS-OSC.md       # Phase-locked bias notes
    └── Hysteresis_Models/            # Physics documentation + images
```

## Building & Testing

### FAUST Version

```bash
cd faust
faust2juce -osc ja_streaming_bias_proto.dsp
cd ja_streaming_bias_proto
cmake -S . -B build -G Xcode
cmake --build build --config Release
```

### C++ JUCE Version

```bash
cd juce_plugin
git clone https://github.com/juce-framework/JUCE.git
cmake -S . -B build -G Xcode
cmake --build build --config Release
```

### A/B Comparison

Both plugins are designed to match exactly:
- Same physics parameters
- Same substep counts (K32=36, K48=54, K60=66)
- Same DC blocker (10 Hz)
- Same parameter ranges and defaults

Load both in your DAW to compare CPU usage and sound quality.

## Key Files

### `faust/ja_streaming_bias_proto.dsp`

The main FAUST prototype implementing:

- **Physics parameters** (lines 5-9): Ms, a_density, k_pinning, c_reversibility, alpha_coupling
- **fast_tanh approximation** (lines 55-60): `t * (27 + x²) / (27 + 9x²)`
- **ja_substep()** (lines 71-98): Core JA physics step
- **Sin/cos recurrence** (lines 100-111): Efficient bias oscillator via angle addition
- **Unrolled loops** (lines 115-181): ja_loop36, ja_loop54, ja_loop66
- **Mode selector** (lines 183-211): Switches between K32/K48/K60

### `juce_plugin/`

Minimal JUCE plugin wrapping the C++ JAHysteresisScheduler:
- Hardcoded to "Normal" quality (matching FAUST substep counts)
- Generic UI for parameter control
- Same parameter names and ranges as FAUST

### `cpp_reference/JAHysteresisScheduler.*`

The C++ implementation with:
- Quality levels (Eco/Normal/Ultra) for CPU scaling
- Direct `sin()` calls instead of recurrence
- Physics equations identical to FAUST

## Technical Notes

### Why Unrolled Loops?

FAUST doesn't support runtime-variable iteration counts, so we use explicit unrolled chains:

```faust
: ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc  // ... repeated N times
```

This works but generates large C++ code. A library-level solution or macro system could help.

### Sin/Cos Recurrence

The prototype uses angle-addition formulas to avoid calling `sin()` per substep:

```faust
s_next = s * cD + c * sD;  // sin(θ + Δ) = sin(θ)cos(Δ) + cos(θ)sin(Δ)
c_next = c * cD - s * sD;  // cos(θ + Δ) = cos(θ)cos(Δ) - sin(θ)sin(Δ)
```

Only the initial `sin(phi_start)` and `cos(phi_start)` plus the step deltas `sin(D)`, `cos(D)` are computed per sample.

### Magnetization Averaging

The output is the sum of all substep magnetizations divided by substep count:

```faust
: ba.selector(0, 3) : *(inv_36)  // Select M_sum, divide by 36
```

This removes the bias frequency while preserving the audio-rate saturation curve.

## Questions for GRAME

1. Is there a more idiomatic way to handle the iterative substep loop in FAUST?
2. Could this become a `ja.lib` library with configurable physics parameters?
3. Any suggestions for reducing generated code size while maintaining the unrolled performance?
4. Is the sin/cos recurrence approach optimal, or does FAUST have better built-in patterns?

## License

This code is shared for collaboration purposes with GRAME. Please contact the author for licensing terms for commercial use.

---

Thank you for your interest in helping optimize this tape saturation algorithm!
