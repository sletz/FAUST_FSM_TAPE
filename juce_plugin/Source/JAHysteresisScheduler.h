#pragma once

#include <array>
#include <cmath>
#include <cstddef>

/**
 * JAHysteresisScheduler
 *
 * Prototype hybrid scheduler that keeps the Jiles–Atherton (JA) physics in a
 * Faust-generated routine while moving the high-rate bias oscillator and
 * sub-step sequencing into C++.  This enables future optimisation such as
 * running fewer JA solves when the bias phase only advances partially during
 * a host sample.
 *
 * The current version mirrors the fixed-step behaviour (K24/K36/K60) by
 * advancing a sine bias oscillator with a phase accumulator and executing a
 * configurable number of JA sub-steps per bias cycle.  The API is deliberately
 * small so we can swap the underlying JA implementation (Faust vs. C++)
 * without changing call-sites.
 */
class JAHysteresisScheduler
{
public:
    enum class Mode
    {
        K32 = 0, ///< 2 bias cycles/sample, 16-20 points/cycle (32-40 substeps)
        K48,     ///< 3 cycles/sample, 16-19 points/cycle (48-57 substeps)
        K60      ///< 3 cycles/sample, 20-24 points/cycle (60-72 substeps)
    };

    enum class Quality
    {
        Eco,
        Normal,
        Ultra
    };

    struct PhysicsParams
    {
        double Ms = 320.0;
        double aDensity = 720.0;
        double kPinning = 280.0;
        double cReversibility = 0.18;
        double alphaCoupling = 0.015;
    };

    void initialise(double sampleRate, Mode mode, const PhysicsParams& physics);
    void reset() noexcept;

    void setMode(Mode mode) noexcept;
    void setPhysics(const PhysicsParams& physics) noexcept;
    void setBiasControls(double biasLevel, double biasScale) noexcept;
    void setQuality(Quality quality) noexcept;

    /** Process one host sample worth of audio field and return averaged magnetisation. */
    double process(double HAudio) noexcept;

private:
    // --- configuration -----------------------------------------------------
    double sampleRate { 48000.0 };
    Mode currentMode { Mode::K32 };
    PhysicsParams physics {};
    double biasLevel { 0.4 };
    double biasScale { 11.0 };

    // --- derived constants -------------------------------------------------
    double MsSafe { 1.0 };
    double alphaNorm { 0.0 };
    double aNorm { 1.0 };
    double invANorm { 1.0 };
    double kNorm { 0.0 };
    double cNorm { 0.0 };
    double biasAmplitude { 0.0 };

    // Bias oscillator
    double biasCyclesPerSample { 2.0 };
    int substepsPerCycle { 12 };
    double biasPhase { 0.0 };
    double substepPhase { 0.0 };
    Quality qualityMode { Quality::Normal };
    double substepCursor { 0.0 };

    // JA state
    double MPrev { 0.0 };
    double HPrev { 0.0 };

    // --- helpers -----------------------------------------------------------
    void updateDerived() noexcept;
    void updateModeDerived() noexcept;
    double fastTanh(double x) const noexcept;
    void executeSubstep(double biasOffset, double HAudio, double& magnetisationSum) noexcept;
};
