#pragma once

#include <juce_audio_processors/juce_audio_processors.h>
#include <juce_dsp/juce_dsp.h>
#include "JAHysteresisScheduler.h"

/**
 * Minimal JA Hysteresis plugin for A/B comparison with FAUST version.
 * Parameters match ja_streaming_bias_proto.dsp exactly.
 */
class JAHysteresisProcessor : public juce::AudioProcessor
{
public:
    JAHysteresisProcessor();
    ~JAHysteresisProcessor() override = default;

    void prepareToPlay(double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages) override;

    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return false; } // Generic UI only

    const juce::String getName() const override { return "JA Hysteresis C++"; }
    bool acceptsMidi() const override { return false; }
    bool producesMidi() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int) override {}
    const juce::String getProgramName(int) override { return {}; }
    void changeProgramName(int, const juce::String&) override {}

    void getStateInformation(juce::MemoryBlock& destData) override;
    void setStateInformation(const void* data, int sizeInBytes) override;

private:
    // Parameters (matching FAUST prototype)
    juce::AudioParameterFloat* inputGainParam;
    juce::AudioParameterFloat* outputGainParam;
    juce::AudioParameterFloat* driveParam;
    juce::AudioParameterFloat* biasLevelParam;
    juce::AudioParameterFloat* biasScaleParam;
    juce::AudioParameterChoice* modeParam;
    juce::AudioParameterFloat* biasRatioParam;
    juce::AudioParameterFloat* mixParam;

    // Smoothed parameters
    juce::SmoothedValue<float> inputGainSmoothed;
    juce::SmoothedValue<float> outputGainSmoothed;
    juce::SmoothedValue<float> driveSmoothed;
    juce::SmoothedValue<float> mixSmoothed;

    // JA Schedulers (one per channel)
    JAHysteresisScheduler schedulerL;
    JAHysteresisScheduler schedulerR;

    // DC blocker
    juce::dsp::IIR::Filter<double> dcBlockerL;
    juce::dsp::IIR::Filter<double> dcBlockerR;

    // Helpers
    void updateSchedulerSettings();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(JAHysteresisProcessor)
};
