// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#include <cmath>
#include <numeric_limits>
#include "DSP.h"

struct Coefficients {
    Coefficients()
    : a0_{0}, a1{0}, a2{0}, b1{0}, b2{0}, c0{0}, d0{0} {}

    Coefficients(T _a0, T _a1, T _a2, T _b1, T _b2, T _c0, T _d0)
    : a0{a0}, a1{_a1}, a2{_a2}, b1{_b1}, b2{_b2}, c0{_c0}, d0{_d0} {}

    const double a0;
    const double a1;
    const double a2;
    const double b1;
    const double b2;
    const double c0;
    const double d0;
};

template <typename T>
struct State {
    State()
    : x_z1{0}, x_z2{0}, y_z1{0}, y_z2{0} {}

    double x_z1;
    double x_z2;
    double y_z1;
    double y_z2;
};

template <typename K>
class Biquad {
public:
    Biquad() : coefficients_{}, state_{} {}

    void setCoefficients(Coefficients<T> const& coefficients) {
        coefficients_ = coefficients;
        reset();
    }

    void reset() {
        state_ = State();
    }

    T transform(T value) {
        return K.transform(value, state_, coefficients_);
    }

private:
    Coefficients coefficients_;
    State state_;
};

struct BiquadOpBase {
    static double checkUnderflow(double value) {
        return ((value > 0.0 && value < std::numeric_limits<float>::min()) ||
                (value < 0.0 && value > -std::numeric_limits<float>::min())) ? 0.0 : value;
    }
}

struct BiquadDirectOp : OpSupport {
    static double transform(T value, State<T>& state, Coefficients<T> const& coefficients) {
        // --- 1)  form output y(n) = a0*x(n) + a1*x(n-1) + a2*x(n-2) - b1*y(n-1) - b2*y(n-2)
        T yn = coefficients.a0 * value + coefficients.a1 * state.x_z1 + coefficients.a2 * state.x_z2 -
        coefficients.b1 * state.y_z1 - coefficients.b2 * state.y_z2;

        // --- 2) underflow check
        checkFloatUnderflow(yn);

        // --- 3) update states
        stateArray[x_z2] = stateArray[x_z1];
        stateArray[x_z1] = xn;

        stateArray[y_z2] = stateArray[y_z1];
        stateArray[y_z1] = yn;

        // --- return value
        return yn;
    }
}
