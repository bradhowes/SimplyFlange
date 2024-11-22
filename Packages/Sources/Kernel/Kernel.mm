#import "C++/Kernel.hpp"

// This must be done in a source file -- include files cannot see the Swift bridging file.

@import ParameterAddress;

bool Kernel::doSetImmediateParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept {
  // Setting ramped values are safe -- they come from the event loop and are interleaved with rendering
  switch (address) {
    case ParameterAddressDepth: depth_.setImmediate(value, duration); return true;
    case ParameterAddressRate: lfo_.setFrequency(value, duration); return true;
    case ParameterAddressDelay: delay_.setImmediate(value, duration); return true;
    case ParameterAddressFeedback: feedback_.setImmediate(value, duration); return true;
    case ParameterAddressDry: dryMix_.setImmediate(value, duration); return true;
    case ParameterAddressWet: wetMix_.setImmediate(value, duration); return true;
    case ParameterAddressNegativeFeedback: negativeFeedback_.setImmediate(value, duration); return true;
    case ParameterAddressOdd90: odd90_.setImmediate(value, duration); return true;
  }
  return false;
}

bool Kernel::doSetPendingParameterValue(AUParameterAddress address, AUValue value) noexcept {
  switch (address) {
    case ParameterAddressDepth: depth_.setPending(value); break;
    case ParameterAddressRate: lfo_.setFrequencyPending(value); break;
    case ParameterAddressDelay: delay_.setPending(value); break;
    case ParameterAddressFeedback: feedback_.setPending(value); break;
    case ParameterAddressDry: dryMix_.setPending(value); break;
    case ParameterAddressWet: wetMix_.setPending(value); break;
    case ParameterAddressNegativeFeedback: negativeFeedback_.setPending(value); break;
    case ParameterAddressOdd90: odd90_.setPending(value); break;
  }
  return false;
}

AUValue Kernel::doGetImmediateParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressDepth: return depth_.getPending();
    case ParameterAddressRate: return lfo_.frequencyPending();
    case ParameterAddressDelay: return delay_.getPending();
    case ParameterAddressFeedback: return feedback_.getPending();
    case ParameterAddressDry: return dryMix_.getPending();
    case ParameterAddressWet: return wetMix_.getPending();
    case ParameterAddressNegativeFeedback: return negativeFeedback_.getPending();
    case ParameterAddressOdd90: return odd90_.getPending();
  }
  return 0.0;
}
AUValue Kernel::doGetPendingParameterValue(AUParameterAddress address) const noexcept {
  switch (address) {
    case ParameterAddressDepth: return depth_.getPending();
    case ParameterAddressRate: return lfo_.frequencyPending();
    case ParameterAddressDelay: return delay_.getPending();
    case ParameterAddressFeedback: return feedback_.getPending();
    case ParameterAddressDry: return dryMix_.getPending();
    case ParameterAddressWet: return wetMix_.getPending();
    case ParameterAddressNegativeFeedback: return negativeFeedback_.getPending();
    case ParameterAddressOdd90: return odd90_.getPending();
  }
  return 0.0;
}
