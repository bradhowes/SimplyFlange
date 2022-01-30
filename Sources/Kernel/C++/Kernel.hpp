// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DelayBuffer.hpp"
#import "EventProcessor.hpp"
#import "LFO.hpp"
#import "Kernel.h"

/**
 The audio processing kernel that generates a "flange" effect.
 */
class Kernel : public EventProcessor<Kernel> {
public:
  using super = EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   @param maxDelayMilliseconds the max number of seconds of audio samples to keep in delay buffer
   */
  Kernel(const std::string& name, double maxDelayMilliseconds)
  : super(os_log_create(name.c_str(), "Kernel")), maxDelayMilliseconds_{maxDelayMilliseconds},
  delayLines_{}, lfo_()
  {
    lfo_.setWaveform(LFOWaveform::triangle);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   */
  void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
    super::startProcessing(format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate);
    delayPos_.allocateBuffers(format, maxFramesToRender);
  }

  /**
   Start of a rendering operation. Note that actual calls to doRendering() below may contain smaller frameCount values
   due to interleaving of MIDI events.

   @param frameCount the number of frames that will be processed during this rendering pass.
   */
  void prepareToRender(AUAudioFrameCount frameCount) {

    // Generate all delay position values necessary to render `frameCount` samples. Doing so up-front here saves some
    // cycles if odd90 is false or there are more than 2 input channels to render.
    auto scale = depth_ * delayInSamples_;
    auto state = lfo_.saveState();
    auto buffer = delayPos_[0];

    // Obtain delay buffer position values using in-phase LFO values
    for (auto index = 0; index < frameCount; ++index) {
      auto value = DSP::bipolarToUnipolar(lfo_.valueAndIncrement()) * scale;
      assert(value >= 0.0 && value < delayLines_[0].size());
      *buffer++ = value;
    }

    if (odd90_) {
      lfo_.restoreState(state);
      buffer = delayPos_[1];

      // Obtain delay buffer position values using out-of-phase LFO values
      for (auto index = 0; index < frameCount; ++index) {
        auto value = DSP::bipolarToUnipolar(lfo_.quadPhaseValueAndIncrement()) * scale;
        assert(value >= 0.0 && value < delayLines_[1].size());
        *buffer++ = value;
      }
    }
  }

  /**
   Process an AU parameter value change.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value) {
    switch (address) {
      case ParameterAddress_Depth:
        depth_ = value / 100.0;
        break;
      case ParameterAddress_Rate:
        if (value == rate_) return;
        rate_ = value;
        lfo_.setFrequency(rate_);
        break;
      case ParameterAddress_Delay:
        delay_ = value;
        delayInSamples_ = samplesPerMillisecond_ * value;
        break;
      case ParameterAddress_Feedback:
        feedback_ = value / 100.0;
        break;
      case ParameterAddress_DryMix:
        dryMix_ = value / 100.0;
        break;
      case ParameterAddress_WetMix:
        wetMix_ = value / 100.0;
        break;
      case ParameterAddress_NegativeFeedback:
        negativeFeedback_ = value > 0 ? true : false;
        break;
      case ParameterAddress_Odd90:
        odd90_ = value > 0 ? true : false;
        break;
    }
  }

  /**
   Obtain the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const {
    switch (address) {
      case ParameterAddress_Depth: return depth_ * 100.0;
      case ParameterAddress_Rate: return rate_;
      case ParameterAddress_Delay: return delay_;
      case ParameterAddress_Feedback: return feedback_ * 100.0;
      case ParameterAddress_DryMix: return dryMix_ * 100.0;
      case ParameterAddress_WetMix: return wetMix_ * 100.0;
      case ParameterAddress_NegativeFeedback: return negativeFeedback_ ? 1.0 : 0.0;
      case ParameterAddress_Odd90: return odd90_ ? 1.0 : 0.0;
    }
    return 0.0;
  }

private:

  void initialize(int channelCount, double sampleRate) {
    samplesPerMillisecond_ = sampleRate / 1000.0;
    delayInSamples_ = delay_ * samplesPerMillisecond_;
    lfo_.initialize(sampleRate, rate_);

    auto size = maxDelayMilliseconds_ * samplesPerMillisecond_ + 1;
    os_log_with_type(log_, OS_LOG_TYPE_INFO, "delayLine size: %f delayInSamples: %f", size, delayInSamples_);
    delayLines_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      delayLines_.emplace_back(size);
    }
  }

  void doParameterEvent(const AUParameterEvent& event) { setParameterValue(event.parameterAddress, event.value); }

  void doRendering(const std::vector<AUValue*>& ins, const std::vector<AUValue*>& outs, AUAudioFrameCount frameCount) {
    auto signedFeedback = negativeFeedback_ ? -feedback_ : feedback_;
    for (int channel = 0; channel < ins.size(); ++channel) {
      auto input{ins[channel]};
      auto output{outs[channel]};
      auto delayPos{delayPos_[(odd90_ && (channel & 1)) ? 1 : 0]};
      auto& delay{delayLines_[channel]};
      for (int frame = 0; frame < frameCount; ++frame) {
        auto inputSample = *input++;
        auto delayedSample = delay.read(*delayPos++);
        delay.write(inputSample + signedFeedback * delayedSample);
        *output++ = wetMix_ * delayedSample + dryMix_ * inputSample;
      }
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

  double depth_;
  double rate_;
  double delay_;
  double feedback_;
  double dryMix_;
  double wetMix_;
  bool negativeFeedback_;
  bool odd90_;

  double maxDelayMilliseconds_;
  double samplesPerMillisecond_;
  double delayInSamples_;

  std::vector<DelayBuffer<AUValue>> delayLines_;
  LFO<double> lfo_;
  InputBuffer delayPos_;
};
