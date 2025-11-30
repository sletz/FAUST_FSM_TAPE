// Test case: FLAT top-level structure (K28 only)
// Expected: WORKING - correct harmonic imprint, natural noise floor

import("stdfaust.lib");
import("ja_lut_k28.lib");   // 2D LUT for K28: 1.5 cycles, 27 substeps (ultra lofi)

// Streaming JA hysteresis prototype with phase-locked bias oscillator.
// LUT-optimized: 1 real substep + 2D LUT lookup for remainder.
// LUTs precomputed for bias_level=0.41, bias_scale=11.0.
//
// All modes use half-integer bias cycles + odd substeps for rich harmonic content.
// This ensures opposite bias polarity between adjacent samples, introducing
// even harmonics that sound warmer and more musical.
//
// Note: Flat top-level structure required due to FAUST nested with-block issue
// with rdtable lookups. See faust/bugfix/README.md for details.

// ===== Physics parameters (fixed for prototype) =====
Ms              = 320.0;      // Saturation magnetization
a_density       = 720.0;      // Anhysteretic curve shape
k_pinning       = 280.0;      // Coercivity (loop width)
c_reversibility = 0.18;       // Reversibility ratio
alpha_coupling  = 0.015;      // Mean field coupling

// ===== User controls =====
input_gain  = hslider("Input Gain [dB]", 0.0, -24.0, 24.0, 0.1) : ba.db2linear : si.smoo;
output_gain = hslider("Output Gain [dB]", 15.9, -24.0, 48.0, 0.1) : ba.db2linear : si.smoo;
drive_db    = hslider("Drive [dB]", 0.0, -18.0, 18.0, 0.1);
drive_gain  = drive_db : si.smoo : ba.db2linear;

bias_mode = nentry("Bias Mode [style:menu{'K28 Ultra LoFi':0}]", 0, 0, 0, 1);

mix = hslider("Mix [Dry->Wet]", 1.0, 0.0, 1.0, 0.01) : si.smoo;

// ===== Derived constants (fixed bias for LUT) =====
Ms_safe    = ba.if(Ms > 1e-6, Ms, 1e-6);
alpha_norm = alpha_coupling;
a_norm     = a_density / Ms_safe;
k_norm     = k_pinning / Ms_safe;
c_norm     = c_reversibility;
bias_amp   = 0.41 * 11.0;  // Fixed for LUT compatibility

// ===== Precomputed bias lookup tables =====
// All modes use half-integer cycles for rich harmonic content

// K28: 1.5 cycles = 3pi, 27 substeps (ultra lofi)
tablesize_27 = 27;
dphi_27 = 3.0 * ma.PI / tablesize_27;
bias_gen_27(n) = sin((float(ba.period(n)) + 0.5) * dphi_27);
bias_lut_27(idx) = rdtable(tablesize_27, bias_gen_27(tablesize_27), int(idx));

// ===== Constants =====
sigma       = 1e-6;
inv_27      = 1.0 / 27.0;
inv_a_norm  = 1.0 / a_norm;

// ===== Real tanh (we can afford it now with LUT optimization) =====
fast_tanh(x) = ma.tanh(x);

// ===== Generic substep 0 (parameterized by bias LUT) =====
// This is the only substep computed in real-time; the rest comes from LUT.
ja_substep0(bias_val, M_prev, H_prev, H_audio) = M1, H1
with {
  H1 = H_audio + bias_amp * bias_val;
  dH = H1 - H_prev;
  He = H1 + alpha_norm * M_prev;

  x_man   = He * inv_a_norm;
  Man_e   = fast_tanh(x_man);
  Man_e2  = Man_e * Man_e;
  dMan_dH = (1.0 - Man_e2) * inv_a_norm;

  dir      = ba.if(dH >= 0.0, 1.0, -1.0);
  pin      = dir * k_norm - alpha_norm * (Man_e - M_prev);
  inv_pin  = 1.0 / (pin + sigma);

  denom     = 1.0 - c_norm * alpha_norm * dMan_dH;
  inv_denom = 1.0 / (denom + 1e-9);
  dMdH      = (c_norm * dMan_dH + (Man_e - M_prev) * inv_pin) * inv_denom;
  dM_step   = dMdH * dH;

  M_unclamped = M_prev + dM_step;
  M1          = max(-1.0, min(1.0, M_unclamped));
};

// ===== K28 LUT loop (ultra lofi) =====
ja_loop_k28(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_27(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k28(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k28(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_27;
  H_end = H_audio + bias_amp * bias_lut_27(26);
};

// ===== Streaming JA hysteresis (K28 only) =====
ja_hysteresis(H_in) = loopK28(H_in)
with {
  loopK28(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k28; };
};

// ===== Prototype tape stage =====
dc_blocker = fi.SVFTPT.HP2(10.0, 0.7071);
drive_comp = 1.0 / drive_gain;  // Compensate: +6dB drive -> -6dB output

tape_stage(x) =
  x * input_gain
  : *(drive_gain)
  : ja_hysteresis
  : dc_blocker
  : *(drive_comp);

wet_gained = tape_stage : *(output_gain);
tape_channel = ef.dryWetMixer(mix, wet_gained);

process = par(i, 2, tape_channel);
