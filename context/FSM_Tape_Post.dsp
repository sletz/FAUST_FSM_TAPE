import("stdfaust.lib");

// ===== Post-JA processing =====
// Assumes magnetised input from external JAHysteresisScheduler.

// Group 2: SATURATION (for drive compensation)
drive_db_raw      = hgroup("Tape", hgroup("[02] SATURATION",
                       vslider("Drive [dB]", -3.3, -18.0, 33.0, 0.1)));
drive_db_smoothed = drive_db_raw : si.smoo;

// Group 4: OUTPUT
output_gain = hgroup("Tape", hgroup("[04] OUTPUT",
               vslider("Output Gain [dB]", 0.0, -33.0, 33.0, 0.1)
               : ba.db2linear : si.smoo));
mix = hgroup("Tape", hgroup("[04] OUTPUT",
               vslider("Mix [Dry->Wet]", 1.0, 0.0, 1.0, 0.01) : si.smoo));

clipper_threshold_linear = hgroup("Tape", hgroup("[04] OUTPUT",
                             vslider("Clipper Threshold [dB]", -0.1, -24.0, 0.0, 0.1)
                             : ba.db2linear));

// Group 5: TOGGLE
clipper_bypass = hgroup("Tape", hgroup("[05] TOGGLE", checkbox("Clipper Bypass")));
quality_mode = hgroup("Tape", hgroup("[05] TOGGLE",
                 nentry("Quality Mode [Eco:0|Normal:1|Ultra:2]", 1.0, 0.0, 2.0, 1.0)));

// Group 6: BIAS (manual compensation)
bias_resolution = hgroup("Tape", hgroup("[06] BIAS",
                       vslider("Bias Resolution [K32|K48|K60]", 1.0, 0.0, 2.0, 1.0)));
bias_comp_db   = hgroup("Tape", hgroup("[06] BIAS",
                       vslider("Bias Compensation [dB]", 0.0, -12.0, 24.0, 0.1)));
bias_comp_gain = bias_comp_db : ba.db2linear : si.smoo;

// Static gains
drive_comp_gain = (drive_db_smoothed - (-10.7)) * (-0.92) : ba.db2linear;
gain_11_4db     = ba.db2linear(11.4);

// Analog-style clipper with threshold control
analog_soft_clipper(threshold_linear) = clip
with {
    clip(x) = min(x, threshold_linear) : max(_, -threshold_linear);
};

apply_clipper(x) = ba.if(clipper_bypass, x, analog_soft_clipper(clipper_threshold_linear)(x));

// Post-processing chain
tape_post =
    *(gain_11_4db)
  : *(drive_comp_gain)
  : *(bias_comp_gain)
  : fi.dcblockerat(10.0)
  : *(output_gain)
  : apply_clipper;

process = par(i, 2, tape_post);
