#import "C++/Kernel.hpp"

@import ParameterAddress;

void Kernel::setParameterValue(AUParameterAddress address, AUValue value) {
  switch (address) {
    case ParameterAddressDepth: depth_.set(value); break;
    case ParameterAddressRate: lfo_.setFrequency(value); break;
    case ParameterAddressDelay: delay_.set(value); break;
    case ParameterAddressFeedback: feedback_.set(value); break;
    case ParameterAddressDryMix: dryMix_.set(value); break;
    case ParameterAddressWetMix: wetMix_.set(value); break;
    case ParameterAddressNegativeFeedback: negativeFeedback_.set(value); break;
    case ParameterAddressOdd90: odd90_.set(value); break;
  }
}

AUValue Kernel::getParameterValue(AUParameterAddress address) const {
  switch (address) {
    case ParameterAddressDepth: return depth_.get();
    case ParameterAddressRate: return lfo_.frequency();
    case ParameterAddressDelay: return delay_.get();
    case ParameterAddressFeedback: return feedback_.get();
    case ParameterAddressDryMix: return dryMix_.get();
    case ParameterAddressWetMix: return wetMix_.get();
    case ParameterAddressNegativeFeedback: return negativeFeedback_.get();
    case ParameterAddressOdd90: return odd90_.get();
  }
  return 0.0;
}
