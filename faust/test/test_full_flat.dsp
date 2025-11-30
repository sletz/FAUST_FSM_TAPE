// Test case: FLAT top-level structure (ALL K modes)
// Expected: WORKING - correct harmonic imprint, natural noise floor

import("stdfaust.lib");
import("ja_lut_k28.lib");   // 2D LUT for K28: 1.5 cycles, 27 substeps (ultra lofi)
import("ja_lut_k45.lib");   // 2D LUT for K45: 2.5 cycles, 45 substeps (lofi)
import("ja_lut_k63.lib");   // 2D LUT for K63: 3.5 cycles, 63 substeps (vintage)
import("ja_lut_k99.lib");   // 2D LUT for K99: 4.5 cycles, 99 substeps (warm)
import("ja_lut_k121.lib");  // 2D LUT for K121: 5.5 cycles, 121 substeps (standard)
import("ja_lut_k187.lib");  // 2D LUT for K187: 8.5 cycles, 187 substeps (high quality)
import("ja_lut_k253.lib");  // 2D LUT for K253: 11.5 cycles, 253 substeps (detailed)
import("ja_lut_k495.lib");  // 2D LUT for K495: 22.5 cycles, 495 substeps (ultra detailed)
import("ja_lut_k1045.lib"); // 2D LUT for K1045: 47.5 cycles, 1045 substeps (extreme)
import("ja_lut_k2101.lib"); // 2D LUT for K2101: 95.5 cycles, 2101 substeps (beyond physical)

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

bias_mode = nentry("Bias Mode [style:menu{'K28 Ultra LoFi':0;'K45 LoFi':1;'K63 Vintage':2;'K99 Warm':3;'K121 Standard':4;'K187 HQ':5;'K253 Detailed':6;'K495 Ultra':7;'K1045 Extreme':8;'K2101 Beyond':9}]", 4, 0, 9, 1);

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

// K45: 2.5 cycles = 5pi, 45 substeps (lofi)
tablesize_45 = 45;
dphi_45 = 5.0 * ma.PI / tablesize_45;
bias_gen_45(n) = sin((float(ba.period(n)) + 0.5) * dphi_45);
bias_lut_45(idx) = rdtable(tablesize_45, bias_gen_45(tablesize_45), int(idx));

// K63: 3.5 cycles = 7pi, 63 substeps (vintage)
tablesize_63 = 63;
dphi_63 = 7.0 * ma.PI / tablesize_63;
bias_gen_63(n) = sin((float(ba.period(n)) + 0.5) * dphi_63);
bias_lut_63(idx) = rdtable(tablesize_63, bias_gen_63(tablesize_63), int(idx));

// K99: 4.5 cycles = 9pi, 99 substeps (warm)
tablesize_99 = 99;
dphi_99 = 9.0 * ma.PI / tablesize_99;
bias_gen_99(n) = sin((float(ba.period(n)) + 0.5) * dphi_99);
bias_lut_99(idx) = rdtable(tablesize_99, bias_gen_99(tablesize_99), int(idx));

// K121: 5.5 cycles = 11pi, 121 substeps (standard)
tablesize_121 = 121;
dphi_121 = 11.0 * ma.PI / tablesize_121;
bias_gen_121(n) = sin((float(ba.period(n)) + 0.5) * dphi_121);
bias_lut_121(idx) = rdtable(tablesize_121, bias_gen_121(tablesize_121), int(idx));

// K187: 8.5 cycles = 17pi, 187 substeps (high quality)
tablesize_187 = 187;
dphi_187 = 17.0 * ma.PI / tablesize_187;
bias_gen_187(n) = sin((float(ba.period(n)) + 0.5) * dphi_187);
bias_lut_187(idx) = rdtable(tablesize_187, bias_gen_187(tablesize_187), int(idx));

// K253: 11.5 cycles = 23pi, 253 substeps (detailed)
tablesize_253 = 253;
dphi_253 = 23.0 * ma.PI / tablesize_253;
bias_gen_253(n) = sin((float(ba.period(n)) + 0.5) * dphi_253);
bias_lut_253(idx) = rdtable(tablesize_253, bias_gen_253(tablesize_253), int(idx));

// K495: 22.5 cycles = 45pi, 495 substeps (ultra detailed)
tablesize_495 = 495;
dphi_495 = 45.0 * ma.PI / tablesize_495;
bias_gen_495(n) = sin((float(ba.period(n)) + 0.5) * dphi_495);
bias_lut_495(idx) = rdtable(tablesize_495, bias_gen_495(tablesize_495), int(idx));

// K1045: 47.5 cycles = 95pi, 1045 substeps (extreme)
tablesize_1045 = 1045;
dphi_1045 = 95.0 * ma.PI / tablesize_1045;
bias_gen_1045(n) = sin((float(ba.period(n)) + 0.5) * dphi_1045);
bias_lut_1045(idx) = rdtable(tablesize_1045, bias_gen_1045(tablesize_1045), int(idx));

// K2101: 95.5 cycles = 191pi, 2101 substeps (beyond physical)
tablesize_2101 = 2101;
dphi_2101 = 191.0 * ma.PI / tablesize_2101;
bias_gen_2101(n) = sin((float(ba.period(n)) + 0.5) * dphi_2101);
bias_lut_2101(idx) = rdtable(tablesize_2101, bias_gen_2101(tablesize_2101), int(idx));

// ===== Inverse substep counts =====
sigma       = 1e-6;
inv_27      = 1.0 / 27.0;
inv_45      = 1.0 / 45.0;
inv_63      = 1.0 / 63.0;
inv_99      = 1.0 / 99.0;
inv_121     = 1.0 / 121.0;
inv_187     = 1.0 / 187.0;
inv_253     = 1.0 / 253.0;
inv_495     = 1.0 / 495.0;
inv_1045    = 1.0 / 1045.0;
inv_2101    = 1.0 / 2101.0;
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

// ===== K45 LUT loop (lofi) =====
ja_loop_k45(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_45(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k45(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k45(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_45;
  H_end = H_audio + bias_amp * bias_lut_45(44);
};

// ===== K63 LUT loop (vintage) =====
ja_loop_k63(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_63(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k63(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k63(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_63;
  H_end = H_audio + bias_amp * bias_lut_63(62);
};

// ===== K99 LUT loop (warm) =====
ja_loop_k99(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_99(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k99(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k99(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_99;
  H_end = H_audio + bias_amp * bias_lut_99(98);
};

// ===== K121 LUT loop (standard) =====
ja_loop_k121(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_121(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k121(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k121(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_121;
  H_end = H_audio + bias_amp * bias_lut_121(120);
};

// ===== K187 LUT loop (high quality) =====
ja_loop_k187(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_187(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k187(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k187(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_187;
  H_end = H_audio + bias_amp * bias_lut_187(186);
};

// ===== K253 LUT loop (detailed) =====
ja_loop_k253(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_253(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k253(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k253(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_253;
  H_end = H_audio + bias_amp * bias_lut_253(252);
};

// ===== K495 LUT loop (ultra detailed) =====
ja_loop_k495(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_495(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k495(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k495(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_495;
  H_end = H_audio + bias_amp * bias_lut_495(494);
};

// ===== K1045 LUT loop (extreme) =====
ja_loop_k1045(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_1045(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k1045(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k1045(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_1045;
  H_end = H_audio + bias_amp * bias_lut_1045(1044);
};

// ===== K2101 LUT loop (beyond physical) =====
ja_loop_k2101(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
with {
  M1_H1 = ja_substep0(bias_lut_2101(0), M_prev, H_prev, H_audio);
  M1 = ba.selector(0, 2, M1_H1);
  M_end = ja_lookup_m_end_k2101(M1, H_audio);
  sumM_rest = ja_lookup_sum_m_rest_k2101(M1, H_audio);
  Mavg = (M1 + sumM_rest) * inv_2101;
  H_end = H_audio + bias_amp * bias_lut_2101(2100);
};

// ===== Streaming JA hysteresis with mode selection (10 modes) =====
ja_hysteresis(H_in) =
  ba.if(bias_mode < 0.5, loopK28(H_in),
  ba.if(bias_mode < 1.5, loopK45(H_in),
  ba.if(bias_mode < 2.5, loopK63(H_in),
  ba.if(bias_mode < 3.5, loopK99(H_in),
  ba.if(bias_mode < 4.5, loopK121(H_in),
  ba.if(bias_mode < 5.5, loopK187(H_in),
  ba.if(bias_mode < 6.5, loopK253(H_in),
  ba.if(bias_mode < 7.5, loopK495(H_in),
  ba.if(bias_mode < 8.5, loopK1045(H_in),
                         loopK2101(H_in))))))))))
with {
  loopK28(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k28; };

  loopK45(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k45; };

  loopK63(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k63; };

  loopK99(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k99; };

  loopK121(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k121; };

  loopK187(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k187; };

  loopK253(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k253; };

  loopK495(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k495; };

  loopK1045(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k1045; };

  loopK2101(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
  with { loop(recM, recH) = recM, recH, H : ja_loop_k2101; };
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
