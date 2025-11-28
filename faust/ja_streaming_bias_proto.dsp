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
input_gain  = hslider("Input Gain [dB]", 0.0, -24.0, 24.0, 0.1) : ba.db2linear : si.smoo;
output_gain = hslider("Output Gain [dB]", 34.0, -24.0, 48.0, 0.1) : ba.db2linear : si.smoo;
drive_db    = hslider("Drive [dB]", -10.0, -18.0, 18.0, 0.1);
drive_gain  = drive_db : si.smoo : ba.db2linear;

bias_level      = hslider("Bias Level", 0.4, 0.0, 1.0, 0.01) : si.smoo;
bias_scale      = hslider("Bias Scale", 11.0, 1.0, 100.0, 0.1) : si.smoo;
bias_resolution = hslider("Bias Resolution [K32|K48|K60]", 1.0, 0.0, 2.0, 1.0);
bias_ratio      = hslider("Bias Ratio", 1.0, 0.98, 1.02, 0.001) : si.smoo;

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
bias_freq_base  = phase_cycles * ma.SR;
bias_freq       = bias_freq_base * bias_ratio;

// Running bias phase: integrate frequency, wrap to 2π, expose previous sample phase.
phase_inc       = two_pi * bias_freq / ma.SR;
phi_unwrapped   = phase_inc : (+ ~ _);
phi_wrapped     = two_pi * ma.frac(phi_unwrapped * inv_two_pi);
phi_start       = phi_wrapped @ 1;
phase_span      = phase_inc;

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

// ===== Sin/cos recurrence =====
ja_step_sc(M_prev, H_prev, H_audio, M_sum_prev, s, c, sD, cD) =
  M_sum_next, M_new, H_new, H_audio, s_next, c_next, sD, cD
with {
  ja_result  = (M_prev, H_prev, H_audio, M_sum_prev) : ja_substep(s);
  M_sum_next = ba.selector(0, 4, ja_result);
  M_new      = ba.selector(1, 4, ja_result);
  H_new      = ba.selector(2, 4, ja_result);

  s_next = s * cD + c * sD;
  c_next = c * cD - s * sD;
};

// ===== Loop helpers (matching C++ Normal quality substep counts) =====

// K32: 36 substeps (2 cycles × 18 points/cycle)
ja_loop36(M_prev, H_prev, H_audio, phi_b, dphi_) =
  M_prev, H_prev, H_audio, 0.0,
  s0, c0, sD, cD
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  <: ba.selector(0, 8), ba.selector(1, 8), ba.selector(2, 8)
with {
  N  = 36.0;
  D  = dphi_ / N;
  sD = sin(D);
  cD = cos(D);
  s0 = sin(phi_b + 0.5 * D);
  c0 = cos(phi_b + 0.5 * D);
};

// K48: 54 substeps (3 cycles × 18 points/cycle)
ja_loop54(M_prev, H_prev, H_audio, phi_b, dphi_) =
  M_prev, H_prev, H_audio, 0.0,
  s0, c0, sD, cD
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  <: ba.selector(0, 8), ba.selector(1, 8), ba.selector(2, 8)
with {
  N  = 54.0;
  D  = dphi_ / N;
  sD = sin(D);
  cD = cos(D);
  s0 = sin(phi_b + 0.5 * D);
  c0 = cos(phi_b + 0.5 * D);
};

// K60: 66 substeps (3 cycles × 22 points/cycle)
ja_loop66(M_prev, H_prev, H_audio, phi_b, dphi_) =
  M_prev, H_prev, H_audio, 0.0,
  s0, c0, sD, cD
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc : ja_step_sc
  <: ba.selector(0, 8), ba.selector(1, 8), ba.selector(2, 8)
with {
  N  = 66.0;
  D  = dphi_ / N;
  sD = sin(D);
  cD = cos(D);
  s0 = sin(phi_b + 0.5 * D);
  c0 = cos(phi_b + 0.5 * D);
};

// ===== Streaming JA hysteresis =====
ja_hysteresis(H_in) =
  ba.if(bias_resolution < 0.5,
    loopK32(H_in),
    ba.if(bias_resolution < 1.5,
      loopK48(H_in),
      loopK60(H_in)))
with {
  loopK32(H) = (loop ~ (mem, mem))
    : ba.selector(0, 3)
    : *(inv_36)
  with {
    loop(recM, recH) = recM, recH, H, phi_start, phase_span : ja_loop36;
  };

  loopK48(H) = (loop ~ (mem, mem))
    : ba.selector(0, 3)
    : *(inv_54)
  with {
    loop(recM, recH) = recM, recH, H, phi_start, phase_span : ja_loop54;
  };

  loopK60(H) = (loop ~ (mem, mem))
    : ba.selector(0, 3)
    : *(inv_66)
  with {
    loop(recM, recH) = recM, recH, H, phi_start, phase_span : ja_loop66;
  };
};

// ===== Prototype tape stage (no limiter/clipper) =====
tape_stage(x) =
  x * input_gain
  : *(drive_gain)
  : ja_hysteresis
  : fi.dcblockerat(10);

wet_gained = tape_stage : *(output_gain);

// Dry/wet mix for quick listening tests.
tape_channel = ef.dryWetMixer(mix, wet_gained);

process = tape_channel, tape_channel;
