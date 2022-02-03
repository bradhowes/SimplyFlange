// Copyright © 2022 Brad Howes. All rights reserved.

#pragma once

#import "RampingParameter.hpp"

template <typename T>
struct MillisecondsParameter : public RampingParameter<T> {
public:
  using super = RampingParameter<T>;

  MillisecondsParameter() = default;
  explicit MillisecondsParameter(T milliseconds) : super(milliseconds) {}
  ~MillisecondsParameter() = default;
};

