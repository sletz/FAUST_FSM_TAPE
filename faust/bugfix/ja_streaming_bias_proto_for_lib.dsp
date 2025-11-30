import("stdfaust.lib");
import("ja_lut_k28.lib");   // 2D LUT for K28 substeps 1..26 (ultra lofi)
import("ja_lut_k32.lib");   // 2D LUT for K32 substeps 1..35 (lofi)
import("ja_lut_k60.lib");   // 2D LUT for K60 substeps 1..65 (vintage)
import("ja_lut_k90.lib");   // 2D LUT for K90 substeps 1..98 (warm)
import("ja_lut_k120.lib");  // 2D LUT for K120 substeps 1..131 (standard)
import("ja_lut_k180.lib");  // 2D LUT for K180 substeps 1..197 (high quality)
import("ja_lut_k240.lib");  // 2D LUT for K240 substeps 1..263
import("ja_lut_k480.lib");  // 2D LUT for K480 substeps 1..527
import("ja_lut_k960.lib");  // 2D LUT for K960 substeps 1..1055
import("ja_lut_k1920.lib"); // 2D LUT for K1920 substeps 1..2111 (beyond physical)

//-----------------tape_channel--------------------
// Phase-locked streaming Jiles-Atherton tape stage: one explicit substep
// per sample plus LUT-accelerated remainder, with fixed bias amplitude and
// mode-selectable bias oscillators (K28..K1920). Drive is applied, then the
// JA hysteresis core runs, DC is blocked, drive is compensated, and the wet
// signal is blended to dry.
//
// #### Usage
//
// ```
// _ : tape_channel(input_gain_db, output_gain_db, drive_db, bias_mode, mix) : _;
// ```
//
// Where:
//
// * input_gain_db: front-end gain in dB.
// * output_gain_db: post-stage gain in dB.
// * drive_db: pre-saturation drive in dB.
// * bias_mode: selects the LUT resolution/flavour (K28..K1920).
// * mix: dry/wet blend from 0 (dry) to 1 (wet).
//
// #### Example
//
// ```
// process = par(i, 2, tape_channel(0.0, 15.9, 0.0, 4, 1.0));
// ```
//
// #### Test
// ```
// tape_channel_test = par(i, 2, tape_channel(0.0, 15.9, 0.0, 4, 1.0));
// ```
//
// #### References [TODO]
//
//-------------------------------------------------
tape_channel(input_gain_db, output_gain_db, drive_db, bias_mode_val, mix_val) =
  ef.dryWetMixer(mix_val, wet_gained)
with {
  drive_gain     = ba.db2linear(drive_db);
  input_gain_lin = ba.db2linear(input_gain_db);
  output_gain_lin = ba.db2linear(output_gain_db);
  drive_comp     = 1.0 / drive_gain;  // Compensate: +6dB drive -> -6dB output

  wet_gained = tape_stage(input_gain_lin, drive_gain, bias_mode_val)
               : *(drive_comp)
               : *(output_gain_lin);

  // ===== Physics parameters (fixed for prototype) =====
  Ms              = 320.0;
  a_density       = 720.0;
  k_pinning       = 280.0;
  c_reversibility = 0.18;
  alpha_coupling  = 0.015;

  // ===== Derived constants (fixed bias for LUT) =====
  Ms_safe    = ba.if(Ms > 1e-6, Ms, 1e-6);
  alpha_norm = alpha_coupling;
  a_norm     = a_density / Ms_safe;
  k_norm     = k_pinning / Ms_safe;
  c_norm     = c_reversibility;
  bias_amp   = 0.41 * 11.0;  // Fixed for LUT compatibility

  // ===== Precomputed bias lookup tables =====
  // K28: 1.5 cycles = 3pi, 27 substeps (ultra lofi)
  tablesize_27 = 27;
  dphi_27 = 3.0 * ma.PI / tablesize_27;
  bias_gen_27(n) = sin((float(ba.period(n)) + 0.5) * dphi_27);
  bias_lut_27(idx) = rdtable(tablesize_27, bias_gen_27(tablesize_27), int(idx));

  // K32: 2 cycles = 4pi, 36 substeps (lofi character)
  tablesize_36 = 36;
  dphi_36 = 4.0 * ma.PI / tablesize_36;
  bias_gen_36(n) = sin((float(ba.period(n)) + 0.5) * dphi_36);
  bias_lut_36(idx) = rdtable(tablesize_36, bias_gen_36(tablesize_36), int(idx));

  // K60: 3 cycles = 6pi, 66 substeps (vintage)
  tablesize_66 = 66;
  dphi_66 = 6.0 * ma.PI / tablesize_66;
  bias_gen_66(n) = sin((float(ba.period(n)) + 0.5) * dphi_66);
  bias_lut_66(idx) = rdtable(tablesize_66, bias_gen_66(tablesize_66), int(idx));

  // K90: 4.5 cycles = 9pi, 99 substeps (warm)
  tablesize_99 = 99;
  dphi_99 = 9.0 * ma.PI / tablesize_99;
  bias_gen_99(n) = sin((float(ba.period(n)) + 0.5) * dphi_99);
  bias_lut_99(idx) = rdtable(tablesize_99, bias_gen_99(tablesize_99), int(idx));

  // K120: 6 cycles = 12pi, 132 substeps (standard)
  tablesize_132 = 132;
  dphi_132 = 12.0 * ma.PI / tablesize_132;
  bias_gen_132(n) = sin((float(ba.period(n)) + 0.5) * dphi_132);
  bias_lut_132(idx) = rdtable(tablesize_132, bias_gen_132(tablesize_132), int(idx));

  // K180: 9 cycles = 18pi, 198 substeps (high quality)
  tablesize_198 = 198;
  dphi_198 = 18.0 * ma.PI / tablesize_198;
  bias_gen_198(n) = sin((float(ba.period(n)) + 0.5) * dphi_198);
  bias_lut_198(idx) = rdtable(tablesize_198, bias_gen_198(tablesize_198), int(idx));

  // K240: 12 cycles = 24pi, 264 substeps
  tablesize_264 = 264;
  dphi_264 = 24.0 * ma.PI / tablesize_264;
  bias_gen_264(n) = sin((float(ba.period(n)) + 0.5) * dphi_264);
  bias_lut_264(idx) = rdtable(tablesize_264, bias_gen_264(tablesize_264), int(idx));

  // K480: 24 cycles = 48pi, 528 substeps
  tablesize_528 = 528;
  dphi_528 = 48.0 * ma.PI / tablesize_528;
  bias_gen_528(n) = sin((float(ba.period(n)) + 0.5) * dphi_528);
  bias_lut_528(idx) = rdtable(tablesize_528, bias_gen_528(tablesize_528), int(idx));

  // K960: 48 cycles = 96pi, 1056 substeps
  tablesize_1056 = 1056;
  dphi_1056 = 96.0 * ma.PI / tablesize_1056;
  bias_gen_1056(n) = sin((float(ba.period(n)) + 0.5) * dphi_1056);
  bias_lut_1056(idx) = rdtable(tablesize_1056, bias_gen_1056(tablesize_1056), int(idx));

  // K1920: 96 cycles = 192pi, 2112 substeps (ultra resolution)
  tablesize_2112 = 2112;
  dphi_2112 = 192.0 * ma.PI / tablesize_2112;
  bias_gen_2112(n) = sin((float(ba.period(n)) + 0.5) * dphi_2112);
  bias_lut_2112(idx) = rdtable(tablesize_2112, bias_gen_2112(tablesize_2112), int(idx));

  sigma       = 1e-6;
  inv_27      = 1.0 / 27.0;
  inv_36      = 1.0 / 36.0;
  inv_66      = 1.0 / 66.0;
  inv_99      = 1.0 / 99.0;
  inv_132     = 1.0 / 132.0;
  inv_198     = 1.0 / 198.0;
  inv_264     = 1.0 / 264.0;
  inv_528     = 1.0 / 528.0;
  inv_1056    = 1.0 / 1056.0;
  inv_2112    = 1.0 / 2112.0;
  inv_a_norm  = 1.0 / a_norm;

  // ===== Real tanh (we can afford it now with LUT optimization) =====
  fast_tanh(x) = ma.tanh(x);

  // ===== Generic substep 0 (parameterized by bias LUT) =====
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

  // ===== K32 LUT loop (lofi) =====
  ja_loop_k32(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_36(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k32(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k32(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_36;
    H_end = H_audio + bias_amp * bias_lut_36(35);
  };

  // ===== K60 LUT loop (vintage) =====
  ja_loop_k60(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_66(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k60(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k60(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_66;
    H_end = H_audio + bias_amp * bias_lut_66(65);
  };

  // ===== K90 LUT loop (warm) =====
  ja_loop_k90(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_99(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k90(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k90(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_99;
    H_end = H_audio + bias_amp * bias_lut_99(98);
  };

  // ===== K120 LUT loop (standard) =====
  ja_loop_k120(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_132(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k120(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k120(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_132;
    H_end = H_audio + bias_amp * bias_lut_132(131);
  };

  // ===== K180 LUT loop (high quality) =====
  ja_loop_k180(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_198(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k180(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k180(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_198;
    H_end = H_audio + bias_amp * bias_lut_198(197);
  };

  // ===== K240 LUT loop =====
  ja_loop_k240(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_264(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k240(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k240(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_264;
    H_end = H_audio + bias_amp * bias_lut_264(263);
  };

  // ===== K480 LUT loop =====
  ja_loop_k480(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_528(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k480(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k480(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_528;
    H_end = H_audio + bias_amp * bias_lut_528(527);
  };

  // ===== K960 LUT loop =====
  ja_loop_k960(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_1056(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k960(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k960(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_1056;
    H_end = H_audio + bias_amp * bias_lut_1056(1055);
  };

  // ===== K1920 LUT loop (ultra) =====
  ja_loop_k1920(M_prev, H_prev, H_audio) = M_end, H_end, Mavg
  with {
    M1_H1 = ja_substep0(bias_lut_2112(0), M_prev, H_prev, H_audio);
    M1 = ba.selector(0, 2, M1_H1);
    M_end = ja_lookup_m_end_k1920(M1, H_audio);
    sumM_rest = ja_lookup_sum_m_rest_k1920(M1, H_audio);
    Mavg = (M1 + sumM_rest) * inv_2112;
    H_end = H_audio + bias_amp * bias_lut_2112(2111);
  };

  // ===== Streaming JA hysteresis with mode selection (10 modes) =====
  ja_hysteresis(bias_mode_val, H_in) =
    ba.if(bias_mode_val < 0.5, loopK28(H_in),
    ba.if(bias_mode_val < 1.5, loopK32(H_in),
    ba.if(bias_mode_val < 2.5, loopK60(H_in),
    ba.if(bias_mode_val < 3.5, loopK90(H_in),
    ba.if(bias_mode_val < 4.5, loopK120(H_in),
    ba.if(bias_mode_val < 5.5, loopK180(H_in),
    ba.if(bias_mode_val < 6.5, loopK240(H_in),
    ba.if(bias_mode_val < 7.5, loopK480(H_in),
    ba.if(bias_mode_val < 8.5, loopK960(H_in),
                                loopK1920(H_in))))))))))
  with {
    loopK28(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k28; };

    loopK32(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k32; };

    loopK60(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k60; };

    loopK90(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k90; };

    loopK120(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k120; };

    loopK180(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k180; };

    loopK240(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k240; };

    loopK480(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k480; };

    loopK960(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k960; };

    loopK1920(H) = (loop ~ (mem, mem)) : ba.selector(2, 3)
    with { loop(recM, recH) = recM, recH, H : ja_loop_k1920; };
  };

  // ===== Prototype tape stage =====
  dc_blocker = fi.SVFTPT.HP2(10.0, 0.7071);

  tape_stage(input_gain_lin, drive_gain, bias_mode_val) =
    _ * input_gain_lin
    : *(drive_gain)
    : ja_hysteresis(bias_mode_val)
    : dc_blocker;
};

//-----------------tape_channel_ui--------------------
// UI wrapper that binds sliders to the core `tape_channel` parameters with
// smoothing, exposing the same bias modes and mix control.
//
// #### Usage
//
// ```
// _ : tape_channel_ui : _;
// ```
//
// #### Example
//
// ```
// process = par(i, 2, tape_channel_ui);
// ```
//
// #### Test
// ```
// tape_channel_ui_test = par(i, 2, tape_channel_ui);
// ```
//
// #### References
//
// * README.md (JA hysteresis tape overview)
// * docs/FSM-PHL-SRD-BIAS-OSC.md (phase-locked bias oscillator modes)
// * doc/docs/contributing.md (UI layering guidance)
//-------------------------------------------------
tape_channel_ui =
  tape_channel(input_gain_db, output_gain_db, drive_db_ui, bias_mode_ui, mix_ui)
with {
  input_gain_db  = hslider("Input Gain [dB]", 0.0, -24.0, 24.0, 0.1) : si.smoo;
  output_gain_db = hslider("Output Gain [dB]", 15.9, -24.0, 48.0, 0.1) : si.smoo;
  drive_db_ui    = hslider("Drive [dB]", 0.0, -18.0, 18.0, 0.1) : si.smoo;
  bias_mode_ui   = nentry("Bias Mode [style:menu{'K28 Ultra LoFi':0;'K32 LoFi':1;'K60 Vintage':2;'K90 Warm':3;'K120 Standard':4;'K180 HQ':5;'K240':6;'K480':7;'K960':8;'K1920 Beyond':9}]", 4, 0, 9, 1);
  mix_ui         = hslider("Mix [Dry->Wet]", 1.0, 0.0, 1.0, 0.01) : si.smoo;
};

process = par(i, 2, tape_channel_ui);
