// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "BoolParameter.hpp"
#import "DelayBuffer.hpp"
#import "EventProcessor.hpp"
#import "MillisecondsParameter.hpp"
#import "LFO.hpp"
#import "PercentageParameter.hpp"

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
   */
  Kernel(const std::string& name)
  : super(os_log_create(name.c_str(), "Kernel"))
  {
    lfo_.setWaveform(LFOWaveform::triangle);
  }

  /**
   Update kernel and buffers to support the given format and channel count

   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   @param maxDelayMilliseconds the max number of milliseconds of audio samples to keep in delay buffer
   */
  void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender, double maxDelayMilliseconds) {
    super::startProcessing(format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate, maxDelayMilliseconds);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value);

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const;

private:

  void initialize(int channelCount, double sampleRate, double maxDelayMilliseconds) {
    samplesPerMillisecond_ = sampleRate / 1000.0;
    maxDelayMilliseconds_ = maxDelayMilliseconds;

    lfo_.initialize(sampleRate, 0.0);

    auto size = maxDelayMilliseconds * samplesPerMillisecond_ + 1;
    os_log_with_type(log_, OS_LOG_TYPE_INFO, "delayLine size: %f", size);
    delayLines_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      delayLines_.emplace_back(size);
    }
  }

  void setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration);

  void setParameterFromEvent(const AUParameterEvent& event) {
    if (event.rampDurationSampleFrames == 0) {
      setParameterValue(event.parameterAddress, event.value);
    } else {
      setRampedParameterValue(event.parameterAddress, event.value, event.rampDurationSampleFrames);
    }
  }

  void doRendering(std::vector<AUValue*>& ins, std::vector<AUValue*>& outs, AUAudioFrameCount frameCount) {

    // Advance by frames in outer loop so we can ramp values when they change without having to save/restore state.
    for (int frame = 0; frame < frameCount; ++frame) {

      auto depth = depth_.frameValue();
      auto delay = delay_.frameValue();
      auto feedback = (negativeFeedback_ ? -1.0 : 1.0) * feedback_.frameValue();
      auto wetMix = wetMix_.frameValue();
      auto dryMix = dryMix_.frameValue();

      auto delaySpan = depth - delay;
      auto evenDelay = DSP::bipolarToUnipolar(lfo_.value()) * delaySpan + delay;
      auto oddDelay = odd90_ ? DSP::bipolarToUnipolar(lfo_.quadPhaseValue()) * delaySpan + delay : evenDelay;

      lfo_.increment();

      for (int channel = 0; channel < ins.size(); ++channel) {
        auto inputSample = *ins[channel]++;
        AUValue delayedSample = 0.0;
        delayedSample = delayLines_[channel].read((channel & 1) ? oddDelay : evenDelay);
        delayLines_[channel].write(inputSample + feedback * delayedSample);
        *outs[channel]++ = wetMix * delayedSample + dryMix * inputSample;
      }
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

  MillisecondsParameter<AUValue> depth_;
  MillisecondsParameter<AUValue> delay_;
  PercentageParameter<AUValue> feedback_;
  PercentageParameter<AUValue> dryMix_;
  PercentageParameter<AUValue> wetMix_;
  BoolParameter negativeFeedback_;
  BoolParameter odd90_;

  double samplesPerMillisecond_;
  double maxDelayMilliseconds_;

  std::vector<DelayBuffer<AUValue>> delayLines_;
  LFO<AUValue> lfo_;
  InputBuffer delayPos_;
};
