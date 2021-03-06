// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#include <cmath>
#include "DSP.h"

enum class LFOWaveform { sinusoid, triangle, sawtooth };

/**
 Implementation of a low-frequency oscillator. Supports 3 waveform:

 - sinusoid
 - triangle
 - sawtooth

 Loosely based on code found in "Designing Audio Effect Plugins in C++" by Will C. Pirkle (2019)
 */
template <typename T>
class LFO {
public:

    LFO(T sampleRate, T frequency, LFOWaveform waveform)
    : sampleRate_{sampleRate}, frequency_{frequency}, valueGenerator_{WaveformGenerator(waveform)} {
        reset();
    }

    LFO(T sampleRate, T frequency) : LFO(sampleRate, frequency, LFOWaveform::sinusoid) {}

    LFO() : LFO(44100.0, 1.0, LFOWaveform::sinusoid) {}

    void initialize(T sampleRate, T frequency) {
        sampleRate_ = sampleRate;
        frequency_ = frequency;
        reset();
    }

    void setWaveform(LFOWaveform waveform) {
        valueGenerator_ = WaveformGenerator(waveform);
    }

    void setFrequency(T frequency) {
        frequency_ = frequency;
        phaseIncrement_ = frequency_ / sampleRate_;
    }

    void reset() {
        phaseIncrement_ = frequency_ / sampleRate_;
        moduloCounter_ = phaseIncrement_ > 0 ? 0.0 : 1.0;
    }

    T saveState() const { return moduloCounter_; }

    void restoreState(T value) {
        moduloCounter_ = value;
        quadPhaseCounter_ = incrementModuloCounter(value, 0.25);
    }

    void increment() {
        moduloCounter_ = incrementModuloCounter(moduloCounter_, phaseIncrement_);
        quadPhaseCounter_ = incrementModuloCounter(moduloCounter_, 0.25);
    }

    /**
     Obtain the next value of the oscillator. Advances counter before returning, so this is not idempotent.
     */
    T valueAndIncrement() {
        auto counter = moduloCounter_;
        quadPhaseCounter_ = incrementModuloCounter(counter, 0.25);
        moduloCounter_ = incrementModuloCounter(counter, phaseIncrement_);
        return valueGenerator_(counter);
    }

    T value() { return valueGenerator_(moduloCounter_); }

    /**
     Obtain a 90° advanced value.
     */
    T quadPhaseValue() const { return valueGenerator_(quadPhaseCounter_); }

private:
    using ValueGenerator = std::function<T(T)>;

    static ValueGenerator WaveformGenerator(LFOWaveform waveform) {
        switch (waveform) {
            case LFOWaveform::sinusoid: return sineValue;
            case LFOWaveform::sawtooth: return sawtoothValue;
            case LFOWaveform::triangle: return triangleValue;
        }
    }

    static T wrappedModuloCounter(T counter, T inc) {
        if (inc > 0 && counter >= 1.0) return counter - 1.0;
        if (inc < 0 && counter <= 0.0) return counter + 1.0;
        return counter;
    }

    static T incrementModuloCounter(T counter, T inc) { return wrappedModuloCounter(counter + inc, inc); }
    static T sineValue(T counter) { return DSP::parabolicSine(M_PI - counter * 2.0 * M_PI); }
    static T sawtoothValue(T counter) { return DSP::unipolarToBipolar(counter); }
    static T triangleValue(T counter) { return DSP::unipolarToBipolar(std::abs(DSP::unipolarToBipolar(counter))); }

    T sampleRate_;
    T frequency_;
    std::function<T(T)> valueGenerator_;
    T moduloCounter_ = {0.0};
    T quadPhaseCounter_ = {0.0};
    T phaseIncrement_;
};
