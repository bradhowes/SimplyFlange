// Copyright © 2022 Brad Howes. All rights reserved.

#pragma once

#import "RampingParameter.hpp"

template <typename T>
class PercentageParameter : public RampingParameter<T> {
public:
  using super = RampingParameter<T>;

  PercentageParameter() = default;
  explicit PercentageParameter(T value) : super(value) {}
  ~PercentageParameter() = default;

  void set(T value, AUAudioFrameCount frameCount) { super::set(value / 100.0, frameCount); }

  T get() const { return super::get() * 100.0; }
};
