// Copyright © 2022 Brad Howes. All rights reserved.

#pragma once

#import <AVFoundation/AVFoundation.h>

struct MillisecondsParameter {

  MillisecondsParameter() = default;
  explicit MillisecondsParameter(double milliseconds) : value_{milliseconds} {}
  ~MillisecondsParameter() = default;

  void set(AUValue seconds) { value_ = seconds * 1000.0; }

  AUValue get() const { return value_ / 1000.0; }

  double milliseconds() const { return value_; }

private:
  double value_;

  MillisecondsParameter(const MillisecondsParameter&) = delete;
  MillisecondsParameter(MillisecondsParameter&&) = delete;
  MillisecondsParameter& operator =(const MillisecondsParameter&) = delete;
  MillisecondsParameter& operator =(MillisecondsParameter&&) = delete;
};
