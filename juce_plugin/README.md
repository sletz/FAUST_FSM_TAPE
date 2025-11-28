# JA Hysteresis C++ Plugin

Minimal JUCE plugin wrapping the C++ JAHysteresisScheduler for A/B comparison with the FAUST version.

## Build Instructions

```bash
# Clone JUCE (if not present)
git clone https://github.com/juce-framework/JUCE.git

# Configure and build
cmake -S . -B build -G Xcode
cmake --build build --config Release
```

## Plugin Outputs

After building:
- **VST3**: `build/JA_Hysteresis_CPP_artefacts/Release/VST3/JA Hysteresis C++.vst3`
- **AU**: `build/JA_Hysteresis_CPP_artefacts/Release/AU/JA Hysteresis C++.component`
- **Standalone**: `build/JA_Hysteresis_CPP_artefacts/Release/Standalone/JA Hysteresis C++.app`

## Parameters

| Parameter | Range | Default | Description |
|-----------|-------|---------|-------------|
| Input Gain | -24 to +24 dB | 0 dB | Pre-hysteresis gain |
| Output Gain | -24 to +48 dB | 34 dB | Post-hysteresis makeup |
| Drive | -18 to +18 dB | -10 dB | Drive into hysteresis |
| Bias Level | 0.0 - 1.0 | 0.4 | Bias oscillator amplitude |
| Bias Scale | 1.0 - 100.0 | 11.0 | Bias amplitude multiplier |
| Bias Resolution | K32/K48/K60 | K48 | Substeps per sample |
| Bias Ratio | 0.98 - 1.02 | 1.0 | Fine-tune bias frequency |
| Mix | 0.0 - 1.0 | 1.0 | Dry/wet blend |

## Matching FAUST Version

This plugin is designed to match `../faust/ja_streaming_bias_proto.dsp` exactly:
- Same physics parameters (Ms=320, a=720, k=280, c=0.18, α=0.015)
- Same substep counts (K32=36, K48=54, K60=66) - "Normal" quality
- Same DC blocker at 10 Hz
- Same parameter ranges and defaults

## A/B Testing

1. Build both plugins:
   ```bash
   # FAUST version
   cd ../faust
   faust2juce -osc ja_streaming_bias_proto.dsp
   cd ja_streaming_bias_proto && cmake -S . -B build -G Xcode && cmake --build build --config Release

   # C++ version
   cd ../../juce_plugin
   cmake -S . -B build -G Xcode && cmake --build build --config Release
   ```

2. Load both in your DAW on parallel tracks
3. Match all parameter values
4. Compare CPU usage and sound quality
