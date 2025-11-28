import("stdfaust.lib");
// Streaming JA hysteresis prototype with running bias oscillator.
// Updated to match C++ JAHysteresisScheduler "Normal" quality substep counts.

// ===== Physics parameters (fixed for prototype) =====
Ms              = 320.0;
a_density       = 720.0;
k_pinning       = 280.0;
c_reversibility = 0.18;
alpha_coupling  = 0.015;

// ===== User controls =====
input_gain  = hslider("Input Gain [dB]", -7.0, -24.0, 24.0, 0.1) : ba.db2linear : si.smoo;
output_gain = hslider("Output Gain [dB]", 40.0, -24.0, 48.0, 0.1) : ba.db2linear : si.smoo;
drive_db    = hslider("Drive [dB]", -13.0, -18.0, 18.0, 0.1);
drive_gain  = drive_db : si.smoo : ba.db2linear;

bias_level      = hslider("Bias Level", 0.62, 0.0, 1.0, 0.01) : si.smoo;
bias_scale      = hslider("Bias Scale", 11.0, 1.0, 100.0, 0.1) : si.smoo;
bias_resolution = nentry("Bias Resolution [style:menu{'K32':0;'K48':1;'K60':2}]", 2, 0, 2, 1);

mix = hslider("Mix [Dry->Wet]", 1.0, 0.0, 1.0, 0.01) : si.smoo;

// ===== Derived constants =====
Ms_safe    = ba.if(Ms > 1e-6, Ms, 1e-6);
alpha_norm = alpha_coupling;
a_norm     = a_density / Ms_safe;
k_norm     = k_pinning / Ms_safe;
c_norm     = c_reversibility;
bias_amp   = bias_level * bias_scale;

two_pi     = 2.0 * ma.PI;
inv_two_pi = 1.0 / two_pi;

// Helper to map resolution selector to base cycle count
// K32 = 2 cycles, K48 = 3 cycles, K60 = 3 cycles
phase_cycles_from_mode(res) = ba.if(res < 0.5, 2.0, 3.0);
phase_cycles    = phase_cycles_from_mode(bias_resolution);
bias_freq       = phase_cycles * ma.SR;

// Running bias phase: wrap INSIDE feedback to prevent precision drift.
// Accumulate in [0,1] range, convert to radians after.
phase_inc_norm  = bias_freq / ma.SR;  // cycles per sample (normalized)
phi_norm        = phase_inc_norm : (+ : ma.frac) ~ _;  // wrap inside feedback
phi_wrapped     = phi_norm * two_pi;
phi_start       = phi_wrapped @ 1;
phase_span      = phase_inc_norm * two_pi;

// Diagnostic: monitor effective cycles per audio sample
bias_cycles_per_sample = bias_freq / ma.SR;

sigma           = 1e-6;

// ===== Fast tanh approximation =====
fast_tanh(x) = t * (27.0 + x2) / (27.0 + 9.0 * x2)
with {
  t  = max(-3.0, min(3.0, x));
  x2 = t * t;
};

// ===== Precompute constants (matching C++ Normal quality) =====
// K32: 2 cycles × 18 points = 36 substeps
// K48: 3 cycles × 18 points = 54 substeps
// K60: 3 cycles × 22 points = 66 substeps
inv_36 = 1.0 / 36.0;
inv_54 = 1.0 / 54.0;
inv_66 = 1.0 / 66.0;
inv_a_norm = 1.0 / a_norm;

// ===== Core JA step driven by current bias sample =====
ja_substep(bias_offset) = ja_step
with {
  ja_step(M_prev, H_prev, H_audio, M_sum_prev) = M_sum_new, M_new, H_new, H_audio
  with {
    H_new = H_audio + bias_amp * bias_offset;
    dH    = H_new - H_prev;
    He    = H_new + alpha_norm * M_prev;

    x_man    = He * inv_a_norm;
    Man_e    = fast_tanh(x_man);
    Man_e2   = Man_e * Man_e;
    dMan_dH  = (1.0 - Man_e2) * inv_a_norm;

    dir      = ba.if(dH >= 0.0, 1.0, -1.0);
    pin      = dir * k_norm - alpha_norm * (Man_e - M_prev);
    inv_pin  = 1.0 / (pin + sigma);

    denom     = 1.0 - c_norm * alpha_norm * dMan_dH;
    inv_denom = 1.0 / (denom + 1e-9);
    dMdH      = (c_norm * dMan_dH + (Man_e - M_prev) * inv_pin) * inv_denom;
    dM_step   = dMdH * dH;

    M_unclamped = M_prev + dM_step;
    M_new       = max(-1.0, min(1.0, M_unclamped));
    M_sum_new   = M_sum_prev + M_new;
  };
};

// ===== Substep with direct sin() call (matching C++ std::sin) =====
// Output order matches input order for correct chaining:
// Inputs:  (M_prev, H_prev, H_audio, M_sum_prev, phi, dphi)
// Outputs: (M_new,  H_new,  H_audio, M_sum_new,  phi_next, dphi)
ja_substep_with_phase(M_prev, H_prev, H_audio, M_sum_prev, phi, dphi) =
  M_new, H_new, H_audio, M_sum_new, phi_next, dphi
with {
  bias_offset = sin(phi + 0.5 * dphi);  // midpoint sampling
  ja_out      = (M_prev, H_prev, H_audio, M_sum_prev) : ja_substep(bias_offset);
  M_sum_new   = ba.selector(0, 4, ja_out);
  M_new       = ba.selector(1, 4, ja_out);
  H_new       = ba.selector(2, 4, ja_out);
  phi_next    = phi + dphi;
};

// ===== Loop helpers (matching C++ Normal quality substep counts) =====

// K32: 36 substeps (2 cycles × 18 points/cycle)
// Final outputs: (M_new, H_new, M_sum) at indices (0, 1, 3)
ja_loop36(M_prev, H_prev, H_audio, phi_b, dphi_) =
  M_prev, H_prev, H_audio, 0.0, phi_b, D : seq(i, 36, ja_substep_with_phase)
  <: ba.selector(0, 6), ba.selector(1, 6), ba.selector(3, 6)
with {
  N = 36.0;
  D = dphi_ / N;
};

// K48: 54 substeps (3 cycles × 18 points/cycle)
// Final outputs: (M_new, H_new, M_sum) at indices (0, 1, 3)
ja_loop54(M_prev, H_prev, H_audio, phi_b, dphi_) =
  M_prev, H_prev, H_audio, 0.0, phi_b, D : seq(i, 54, ja_substep_with_phase)
  <: ba.selector(0, 6), ba.selector(1, 6), ba.selector(3, 6)
with {
  N = 54.0;
  D = dphi_ / N;
};

// K60: 66 substeps (3 cycles × 22 points/cycle)
// Output order: M_new, H_new, M_sum (for correct feedback via ~ operator)
ja_loop66(M_prev, H_prev, H_audio, phi_b, dphi_) =
  M_prev, H_prev, H_audio, 0.0, phi_b, D : seq(i, 66, ja_substep_with_phase)
  <: ba.selector(0, 6), ba.selector(1, 6), ba.selector(3, 6)
with {
  N = 66.0;
  D = dphi_ / N;
};

// ===== Streaming JA hysteresis =====
// Output order from ja_loopXX is (M_new, H_new, M_sum) at indices (0, 1, 3)
// Feedback via ~ takes first 2 outputs: M_new -> recM, H_new -> recH (correct!)
// Final output is M_sum at index 2 of the 3-output tuple
ja_hysteresis(H_in) =
  ba.if(bias_resolution < 0.5,
    loopK32(H_in),
    ba.if(bias_resolution < 1.5,
      loopK48(H_in),
      loopK60(H_in)))
with {
  loopK32(H) = (loop ~ (mem, mem))
    : ba.selector(2, 3)    // M_sum is now at index 2
    : *(inv_36)
  with {
    loop(recM, recH) = recM, recH, H, phi_start, phase_span : ja_loop36;
  };

  loopK48(H) = (loop ~ (mem, mem))
    : ba.selector(2, 3)    // M_sum is now at index 2
    : *(inv_54)
  with {
    loop(recM, recH) = recM, recH, H, phi_start, phase_span : ja_loop54;
  };

  loopK60(H) = (loop ~ (mem, mem))
    : ba.selector(2, 3)    // M_sum is now at index 2
    : *(inv_66)
  with {
    loop(recM, recH) = recM, recH, H, phi_start, phase_span : ja_loop66;
  };
};

// ===== Prototype tape stage (no limiter/clipper) =====
// DC blocker: 2nd-order SVF TPT highpass at 10 Hz, Butterworth Q
dc_blocker = fi.SVFTPT.HP2(10.0, 0.7071);

tape_stage(x) =
  x * input_gain
  : *(drive_gain)
  : ja_hysteresis
  : dc_blocker;

wet_gained = tape_stage : *(output_gain);

// Dry/wet mix for quick listening tests.
tape_channel = ef.dryWetMixer(mix, wet_gained);

process = tape_channel, tape_channel;
