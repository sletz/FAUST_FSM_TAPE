cmake_minimum_required(VERSION 3.22)
project(JA_Hysteresis_CPP VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Add JUCE
add_subdirectory(JUCE)

# Plugin target
juce_add_plugin(JA_Hysteresis_CPP
    COMPANY_NAME "OmegaDSP"
    PLUGIN_MANUFACTURER_CODE OmDp
    PLUGIN_CODE JaHy
    FORMATS VST3 AU Standalone
    PRODUCT_NAME "JA Hysteresis C++"
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT FALSE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    COPY_PLUGIN_AFTER_BUILD TRUE
)

target_sources(JA_Hysteresis_CPP
    PRIVATE
        Source/PluginProcessor.cpp
        Source/JAHysteresisScheduler.cpp
)

target_compile_definitions(JA_Hysteresis_CPP
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0
        JUCE_DISPLAY_SPLASH_SCREEN=0
)

target_link_libraries(JA_Hysteresis_CPP
    PRIVATE
        juce::juce_audio_utils
        juce::juce_dsp
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)
