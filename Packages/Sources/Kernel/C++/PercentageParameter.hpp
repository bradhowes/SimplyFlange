// Copyright © 2022 Brad Howes. All rights reserved.

#pragma once

#import <AVFoundation/AVFoundation.h>

struct PercentageParameter {

  PercentageParameter() = default;
  explicit PercentageParameter(double value) : value_{value} {}
  ~PercentageParameter() = default;

  void set(AUValue value) { value_ = value / 100.0; }

  AUValue get() const { return value_ * 100.0; }

  double norm() const { return value_; }

private:
  double value_;

  PercentageParameter(const PercentageParameter&) = delete;
  PercentageParameter(PercentageParameter&&) = delete;
  PercentageParameter& operator =(const PercentageParameter&) = delete;
  PercentageParameter& operator =(PercentageParameter&&) = delete;
};
