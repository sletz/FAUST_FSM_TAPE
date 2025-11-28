# Phase-Locked SR-Driven Bias Oscillator Notes

## Goal
Deliver a tape-hysteresis stage that keeps its sonic character across sample rates while offering controllable "bias resolution" flavours that range from gentle compression to hard tape-style slam.

## Key Changes
- **SR-locked bias phasor**: replaced the free frequency slider with an internal cycle counter (`phase_cycles`) tied to the host sample-rate. Each bias resolution mode now maps to a fixed number of bias cycles per audio sample (K18→2, K24→2, K30→3), so the solver sees identical phase coverage at 44.1, 48, 96, 192 kHz, etc.
- **Midpoint sub-step chains**: rewrote the Jiles–Atherton integration to use configurable midpoint grids (18, 24, 30 steps). These use `sin(phi + (i + 0.5)/K * dphi)` offsets, keeping the bias sine evenly sampled for stability and "tape feel."
- **Resolution-aware gain compensation**: added a calibration slider plus per-mode scaling so that K18/K24/K30 remain loudness-comparable while still showcasing their different compression/saturation behaviour.
- **Removed bias down-sample gate**: eliminated the CPU-saving/bit-crusher option and always run the full JA loop for mastering-grade fidelity.

## Sonic Results
- **K18** – 2 bias cycles/sample. Smooth, slightly compressed bias feel. Good for gentle analog glue.
- **K24** – also 2 cycles/sample but denser midpoints, hits harder; perfect for "tape machine slam."
- **K30** – 3 cycles/sample. Highest fidelity, most even harmonics, tightest transient hold; responds like an optimally biased deck.

With the cycle mapping hard-wired, driving the bias level feels consistent no matter what SR the session uses. The resolution control becomes a creative choice between tape "formulations" rather than a CPU tweak.

## Workflow Tips
- Pick your resolution (K18, K24, K30) based on desired crunch vs. fidelity.
- Use **Bias Compensation [dB]** to loudness-match when A/B’ing modes.
- Adjust **Bias Level** / **Bias Scale** to taste; the internal phasor keeps the same bias sweep curve at every SR.
- Leave limiter/clipper bypasses in the OUTPUT group to shape final tone as needed.

## Files Touched
- `FSM_Tape_LimHardClip.dsp`: SR-locked bias refactor, resolution chains, compensation, gate removal.
- Removed dependency on external bias frequency slider—no longer generated into headers by `generate_fsm_tape_header.sh`.

The result is a phase-locked, SR-driven bias oscillator that delivers consistent tape tone, richer harmonics, and resolution flavours dialled specifically for mastering use.
