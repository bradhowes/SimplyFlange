#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

void Kernel::setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  switch (address) {
    case ParameterAddressDepth: depth_.set(value, duration);
      os_log_debug(log_, "setRampedParameterValue - depth value: %f", value);
      break;
    case ParameterAddressRate: lfo_.setFrequency(value, duration);
      os_log_debug(log_, "setRampedParameterValue - frequency value: %f", value);
      break;
    case ParameterAddressDelay: delay_.set(value, duration);
      os_log_debug(log_, "setRampedParameterValue - delay value: %f", value);
      break;
    case ParameterAddressFeedback: feedback_.set(value, duration);
      os_log_debug(log_, "setRampedParameterValue - feedback value: %f", value);
      break;
    case ParameterAddressDry: dryMix_.set(value, duration);
      os_log_debug(log_, "setRampedParameterValue - dryMix value: %f", value);
      break;
    case ParameterAddressWet: wetMix_.set(value, duration);
      os_log_debug(log_, "setRampedParameterValue - wetMix value: %f", value);
      break;
    case ParameterAddressNegativeFeedback: negativeFeedback_.set(value);
      break;
    case ParameterAddressOdd90: odd90_.set(value);
      break;
  }
}

AUValue Kernel::getParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressDepth:
      os_log_debug(log_, "getParameterValue - depth value: %f", depth_.get());
      return depth_.get();
    case ParameterAddressRate:
      os_log_debug(log_, "getParameterValue - frequency value: %f", lfo_.frequency());
      return lfo_.frequency();
    case ParameterAddressDelay:
      os_log_debug(log_, "getParameterValue - delay value: %f", delay_.get());
      return delay_.get();
    case ParameterAddressFeedback:
      os_log_debug(log_, "getParameterValue - feedback value: %f", feedback_.get());
      return feedback_.get();
    case ParameterAddressDry:
      os_log_debug(log_, "getParameterValue - dryMix value: %f", dryMix_.get());
      return dryMix_.get();
    case ParameterAddressWet:
      os_log_debug(log_, "getParameterValue - wetMix value: %f", wetMix_.get());
      return wetMix_.get();
    case ParameterAddressNegativeFeedback:
      return negativeFeedback_.get();
    case ParameterAddressOdd90:
      return odd90_.get();
  }
  return 0.0;
}
