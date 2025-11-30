// Test case: NESTED with { } structure (K28 only)
// Expected: BROKEN - flat noise floor, aliasing artifacts
// Key: tape_channel is a FUNCTION with parameters (like Stéphane's lib structure)

import("stdfaust.lib");
import("ja_lut_k28.lib");   // 2D LUT for K28: 1.5 cycles, 27 substeps (ultra lofi)

// tape_channel as FUNCTION with parameters - this is the library pattern
tape_channel(input_gain_db, output_gain_db, drive_db, bias_mode_val, mix_val) =
  ef.dryWetMixer(mix_val, wet_gained)
with {
  // ===== Gains from function parameters =====
  input_gain  = ba.db2linear(input_gain_db) : si.smoo;
  output_gain = ba.db2linear(output_gain_db) : si.smoo;
  drive_gain  = ba.db2linear(drive_db) : si.smoo;

  // ===== Physics parameters =====
  Ms              = 320.0;
  a_density       = 720.0;
  k_pinning       = 280.0;
  c_reversibility = 0.18;
  alpha_coupling  = 0.015;

  // ===== Derived constants =====
  Ms_safe    = ba.if(Ms > 1e-6, Ms, 1e-6);
  alpha_norm = alpha_coupling;
  a_norm     = a_density / Ms_safe;
  k_norm     = k_pinning / Ms_safe;
  c_norm     = c_reversibility;
  bias_amp   = 0.41 * 11.0;

  // ===== K28 bias lookup table =====
  tablesize_27 = 27;
  dphi_27 = 3.0 * ma.PI / tablesize_27;
  bias_gen_27(n) = sin((float(ba.period(n)) + 0.5) * dphi_27);
  bias_lut_27(idx) = rdtable(tablesize_27, bias_gen_27(tablesize_27), int(idx));

  // ===== Constants =====
  sigma       = 1e-6;
  inv_27      = 1.0 / 27.0;
  inv_a_norm  = 1.0 / a_norm;

  // ===== Real tanh =====
  fast_tanh(x) = ma.tanh(x);

  // ===== Generic substep 0 =====
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

  // ===== K28 LUT loop =====
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

  // ===== Tape stage =====
  dc_blocker = fi.SVFTPT.HP2(10.0, 0.7071);
  drive_comp = 1.0 / drive_gain;

  tape_stage(x) =
    x * input_gain
    : *(drive_gain)
    : ja_hysteresis
    : dc_blocker
    : *(drive_comp);

  wet_gained = tape_stage : *(output_gain);
};

// UI wrapper - calls the function with slider values
tape_channel_ui =
  tape_channel(input_gain_db, output_gain_db, drive_db, bias_mode, mix)
with {
  input_gain_db  = hslider("Input Gain [dB]", 0.0, -24.0, 24.0, 0.1);
  output_gain_db = hslider("Output Gain [dB]", 15.9, -24.0, 48.0, 0.1);
  drive_db       = hslider("Drive [dB]", 0.0, -18.0, 18.0, 0.1);
  bias_mode      = nentry("Bias Mode [style:menu{'K28 Ultra LoFi':0}]", 0, 0, 0, 1);
  mix            = hslider("Mix [Dry->Wet]", 1.0, 0.0, 1.0, 0.01);
};

process = par(i, 2, tape_channel_ui);
