import("stdfaust.lib");

// ===== Pre-JA processing =====
// Handles input gain, 1176 limiter, head-bump, and drive scaling.

// Group 1: HEADROOM
input_gain = hgroup("Tape", hgroup("[01] HEADROOM",
              vslider("Input Gain [dB]", 0.0, -33.0, 33.0, 0.1)
              : ba.db2linear : si.smoo));

// Group 2: SATURATION
drive_db_raw      = hgroup("Tape", hgroup("[02] SATURATION",
                       vslider("Drive [dB]", -3.3, -33.0, 33.0, 0.1)));
drive_db_smoothed = drive_db_raw : si.smoo;
b_drive           = drive_db_smoothed : ba.db2linear;

// Group 3: H-BUMP
head_bump_gain_db = hgroup("Tape", hgroup("[03] H-BUMP",
                      vslider("Head Bump Gain [dB]", 0.6, -12.0, 12.0, 0.1)));
head_bump_q   = hgroup("Tape", hgroup("[03] H-BUMP",
                  vslider("Head Bump Q", 0.8, 0.1, 5.0, 0.01)));
head_bump     = hgroup("Tape", hgroup("[03] H-BUMP",
                          vslider("Head Bump [Hz]", 65.0, 20.0, 200.0, 1.0)));

// Group 5: TOGGLE
limiter_bypass = hgroup("Tape", hgroup("[05] TOGGLE", checkbox("1176 Bypass")));

// Constants (1176 calibration: -24.5 dB input, +24.5 dB output)
gain_1db       = ba.db2linear(-4.7);
gain_minus1db  = ba.db2linear(4.7);

// 1176 Limiter
fet_limiter_stage = co.limiter_1176_R4_mono;
apply_limiter(x)  = ba.if(limiter_bypass, x, fet_limiter_stage(x));

//ainPreJA = ba.db2linear(18.0);

pre_chain =
    *(input_gain)
  : fi.svf.ls(head_bump, head_bump_q, head_bump_gain_db)
  : *(gain_1db)
  : apply_limiter
  : *(gain_minus1db)
  //: *(gainPreJA)
  : *(b_drive)
  ;

process = par(i, 2, pre_chain);
