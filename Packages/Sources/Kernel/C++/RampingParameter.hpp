#pragma once

#import <AVFoundation/AVFoundation.h>

template <typename T>
struct RampingParameter {
  RampingParameter() = default;
  explicit RampingParameter(AUValue initialValue) : value_{initialValue} {}
  ~RampingParameter() = default;

  void set(T target, AUAudioFrameCount duration) {
    if (duration > 0) {
      rampRemaining_ = duration;
      rampTarget_ = target;
      rampStep_ = (rampTarget_ - value_) / duration;
    } else {
      value_ = target;
      rampRemaining_ = 0;
    }
  }

  /// Internally we use value_, but for everything else, including UI, we never show a ramped value.
  T get() const { return rampRemaining_ ? rampTarget_ : value_; }

  /// Fetch the per-frame value.
  T frameValue() {
    if (rampRemaining_ > 0) {
      if (--rampRemaining_ == 0) {
        value_ = rampTarget_;
      } else {
        value_ += rampStep_;
      }
    }
    return value_;
  }

private:
  T value_;
  T rampTarget_;
  T rampStep_;
  AUAudioFrameCount rampRemaining_{0};

  RampingParameter(const RampingParameter&) = delete;
  RampingParameter(RampingParameter&&) = delete;
  RampingParameter& operator =(const RampingParameter&) = delete;
  RampingParameter& operator =(const RampingParameter&&) = delete;
};
