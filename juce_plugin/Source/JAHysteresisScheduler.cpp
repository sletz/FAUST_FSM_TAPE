#include "JAHysteresisScheduler.h"

#include <algorithm>
#include <cmath>
#include <numbers>

namespace
{
constexpr double kTwoPi = std::numbers::pi * 2.0;
}

void JAHysteresisScheduler::initialise(double newSampleRate,
                                       Mode mode,
                                       const PhysicsParams& newPhysics)
{
    sampleRate = std::max(1.0, newSampleRate);
    currentMode = mode;
    physics = newPhysics;
    biasLevel = std::clamp(biasLevel, 0.0, 1.0);

    reset();
    updateDerived();
    updateModeDerived();
}

void JAHysteresisScheduler::reset() noexcept
{
    biasPhase = 0.0;
    MPrev = 0.0;
    HPrev = 0.0;
    substepCursor = 0.0;
}

void JAHysteresisScheduler::setMode(Mode mode) noexcept
{
    if (currentMode == mode)
        return;

    currentMode = mode;
    updateModeDerived();
}

void JAHysteresisScheduler::setPhysics(const PhysicsParams& newPhysics) noexcept
{
    physics = newPhysics;
    updateDerived();
}

void JAHysteresisScheduler::setBiasControls(double level, double scale) noexcept
{
    biasLevel = std::clamp(level, 0.0, 1.0);
    biasScale = std::max(scale, 0.0);
    updateDerived();
}

void JAHysteresisScheduler::setQuality(Quality quality) noexcept
{
    qualityMode = quality;
    updateModeDerived();
}

double JAHysteresisScheduler::process(double HAudio) noexcept
{
    double magnetisationSum = 0.0;

    substepCursor += biasCyclesPerSample * static_cast<double>(substepsPerCycle);
    int stepsTaken = static_cast<int>(std::floor(substepCursor));
    substepCursor -= static_cast<double>(stepsTaken);

    double phase = biasPhase;

    for (int i = 0; i < stepsTaken; ++i)
    {
        const double midpoint = std::fmod(phase + substepPhase * 0.5, kTwoPi);
        const double biasOffset = std::sin(midpoint);
        executeSubstep(biasOffset, HAudio, magnetisationSum);

        phase += substepPhase;
        if (phase >= kTwoPi)
            phase -= kTwoPi;
    }

    // Advance phase by the leftover fractional sub-step so the next call starts in the right place
    phase += substepCursor * substepPhase;
    if (phase >= kTwoPi)
        phase = std::fmod(phase, kTwoPi);

    biasPhase = phase;

    if (stepsTaken == 0)
    {
        const double midpoint = std::fmod(phase + substepPhase * 0.5, kTwoPi);
        const double biasOffset = std::sin(midpoint);
        executeSubstep(biasOffset, HAudio, magnetisationSum);
        stepsTaken = 1;
    }

    return magnetisationSum / static_cast<double>(stepsTaken);
}

// -----------------------------------------------------------------------------
void JAHysteresisScheduler::updateDerived() noexcept
{
    MsSafe = std::max(physics.Ms, 1.0e-6);
    alphaNorm = physics.alphaCoupling;
    aNorm = physics.aDensity / MsSafe;
    invANorm = 1.0 / std::max(aNorm, 1.0e-9);
    kNorm = physics.kPinning / MsSafe;
    cNorm = physics.cReversibility;
    biasAmplitude = biasLevel * biasScale;
}

void JAHysteresisScheduler::updateModeDerived() noexcept
{
    int ecoSteps = 0, normalSteps = 0, ultraSteps = 0;

    switch (currentMode)
    {
        case Mode::K32:
            biasCyclesPerSample = 2.0;
            ecoSteps = 16;   // 32 substeps / 2 cycles = 16 points/cycle
            normalSteps = 18; // 36 substeps / 2 cycles = 18 points/cycle
            ultraSteps = 20;  // 40 substeps / 2 cycles = 20 points/cycle
            break;
        case Mode::K48:
            biasCyclesPerSample = 3.0;
            ecoSteps = 16;   // 48 substeps / 3 cycles = 16 points/cycle
            normalSteps = 18; // 54 substeps / 3 cycles = 18 points/cycle
            ultraSteps = 19;  // 57 substeps / 3 cycles = 19 points/cycle
            break;
        case Mode::K60:
            biasCyclesPerSample = 3.0;
            ecoSteps = 20;   // 60 substeps / 3 cycles = 20 points/cycle
            normalSteps = 22; // 66 substeps / 3 cycles = 22 points/cycle
            ultraSteps = 24;  // 72 substeps / 3 cycles = 24 points/cycle
            break;
    }

    switch (qualityMode)
    {
        case Quality::Eco:    substepsPerCycle = ecoSteps;    break;
        case Quality::Ultra:  substepsPerCycle = ultraSteps;  break;
        case Quality::Normal:
        default:              substepsPerCycle = normalSteps; break;
    }

    substepsPerCycle = std::max(substepsPerCycle, 4);

    substepPhase = kTwoPi / static_cast<double>(substepsPerCycle);
    if (substepCursor >= 1.0)
        substepCursor = std::fmod(substepCursor, 1.0);
}

double JAHysteresisScheduler::fastTanh(double x) const noexcept
{
    const double clamped = std::clamp(x, -3.0, 3.0);
    const double x2 = clamped * clamped;
    return clamped * (27.0 + x2) / (27.0 + 9.0 * x2);
}

void JAHysteresisScheduler::executeSubstep(double biasOffset,
                                           double HAudio,
                                           double& magnetisationSum) noexcept
{
    const double HNew = HAudio + biasAmplitude * biasOffset;
    const double dH = HNew - HPrev;
    const double He = HNew + alphaNorm * MPrev;

    const double xMan = He * invANorm;
    const double ManE = fastTanh(xMan);
    const double ManE2 = ManE * ManE;
    const double dMan_dH = (1.0 - ManE2) * invANorm;

    const double dir = (dH >= 0.0) ? 1.0 : -1.0;
    const double pin = dir * kNorm - alphaNorm * (ManE - MPrev);
    const double invPin = 1.0 / (pin + 1.0e-6);

    const double denom = 1.0 - cNorm * alphaNorm * dMan_dH;
    const double invDenom = 1.0 / (denom + 1.0e-9);
    const double dMdH = (cNorm * dMan_dH + (ManE - MPrev) * invPin) * invDenom;
    const double dMStep = dMdH * dH;

    const double MNew = std::clamp(MPrev + dMStep, -1.0, 1.0);

    magnetisationSum += MNew;
    MPrev = MNew;
    HPrev = HNew;
}
