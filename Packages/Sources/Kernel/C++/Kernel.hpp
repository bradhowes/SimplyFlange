// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <os/log.h>
#import <algorithm>
#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DSPHeaders/BoolParameter.hpp"
#import "DSPHeaders/DelayBuffer.hpp"
#import "DSPHeaders/EventProcessor.hpp"
#import "DSPHeaders/MillisecondsParameter.hpp"
#import "DSPHeaders/LFO.hpp"
#import "DSPHeaders/PercentageParameter.hpp"

/**
 The audio processing kernel that generates a "flange" effect by combining an audio signal with a slightly delayed copy
 of itself. The delay value oscillates at a defined frequency which causes the delayed audio to vary in pitch due to it
 being sped up or slowed down.
 */
class Kernel : public DSPHeaders::EventProcessor<Kernel> {
public:
  using super = DSPHeaders::EventProcessor<Kernel>;
  friend super;

  /**
   Construct new kernel

   @param name the name to use for logging purposes.
   */
  Kernel(std::string name) noexcept : super(), name_{name}, log_{os_log_create(name_.c_str(), "Kernel")}
  {
    os_log_debug(log_, "constructor");
    lfo_.setWaveform(LFOWaveform::triangle);
  }

  const os_log_t& log() const { return log_; }

  /**
   Update kernel and buffers to support the given format and channel count

   @param format the audio format to render
   @param maxFramesToRender the maximum number of samples we will be asked to render in one go
   @param maxDelayMilliseconds the max number of milliseconds of audio samples to keep in delay buffer
   */
  void setRenderingFormat(NSInteger busCount, AVAudioFormat* format, AUAudioFrameCount maxFramesToRender,
                          double maxDelayMilliseconds) noexcept {
    super::setRenderingFormat(busCount, format, maxFramesToRender);
    initialize(format.channelCount, format.sampleRate, maxDelayMilliseconds);
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   */
  void setParameterValue(AUParameterAddress address, AUValue value) noexcept {
    setRampedParameterValue(address, value, AUAudioFrameCount(50));
  }

  /**
   Process an AU parameter value change by updating the kernel.

   @param address the address of the parameter that changed
   @param value the new value for the parameter
   @param duration the number of samples to adjust over
   */
  void setRampedParameterValue(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) noexcept;

  /**
   Obtain from the kernel the current value of an AU parameter.

   @param address the address of the parameter to return
   @returns current parameter value
   */
  AUValue getParameterValue(AUParameterAddress address) const noexcept;

private:

  void initialize(int channelCount, double sampleRate, double maxDelayMilliseconds) noexcept {
    os_log_debug(log_, "initialize - channelCount: %d sampleRate: %f maxDelayMilliseconds: %f",
                 channelCount, sampleRate, maxDelayMilliseconds);
    samplesPerMillisecond_ = sampleRate / 1000.0;
    maxDelayMilliseconds_ = maxDelayMilliseconds;

    lfo_.setSampleRate(sampleRate);

    auto size = maxDelayMilliseconds * samplesPerMillisecond_ + 1;
    delayLines_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      delayLines_.emplace_back(size);
    }
  }

  void setParameterFromEvent(const AUParameterEvent& event) noexcept {
    setRampedParameterValue(event.parameterAddress, event.value, event.rampDurationSampleFrames);
  }

  void doRenderingStateChanged(bool rendering) {
    if (!rendering) {
      depth_.stopRamping();
      delay_.stopRamping();
      feedback_.stopRamping();
      dryMix_.stopRamping();
      wetMix_.stopRamping();
    }
  }

  void doRendering(NSInteger outputBusNumber, DSPHeaders::BusBuffers ins, DSPHeaders::BusBuffers outs,
                   AUAudioFrameCount frameCount) noexcept {

    // Advance by frames in outer loop so we can ramp values when they change without having to save/restore state.
    for (int frame = 0; frame < frameCount; ++frame) {

      auto depth = depth_.frameValue();
      auto delay = delay_.frameValue();
      auto feedback = (negativeFeedback_ ? -1.0 : 1.0) * feedback_.frameValue();
      auto wetMix = wetMix_.frameValue();
      auto dryMix = dryMix_.frameValue();

      // This is the amount of delay that the LFO can oscillate over. A value of -1 in the LFO will result in 0.0 and a
      // value of +1 from the LFO will give `delaySpan`.
      auto delaySpan = depth - delay;

      // Calculate the delay signal for even channels (L)
      auto evenDelay = DSPHeaders::DSP::bipolarToUnipolar(lfo_.value()) * delaySpan + delay;

      // Optionally, odd channels (R) can be 90° out of phase with the even channels.
      auto oddDelay = odd90_ ? DSPHeaders::DSP::bipolarToUnipolar(lfo_.quadPhaseValue()) * delaySpan + delay : evenDelay;

      // Safe now to increment the LFO for the next frame.
      lfo_.increment();

      // Process the same frame in all of the channels
      for (int channel = 0; channel < ins.size();  ++channel) {
        auto inputSample = ins[channel][frame];
        auto delayedSample = delayLines_[channel].read((channel & 1) ? oddDelay : evenDelay);
        delayLines_[channel].write(inputSample + feedback * delayedSample);
        outs[channel][frame] = wetMix * delayedSample + dryMix * inputSample;
      }
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) noexcept {}

  DSPHeaders::Parameters::MillisecondsParameter<AUValue> depth_;
  DSPHeaders::Parameters::MillisecondsParameter<AUValue> delay_;
  DSPHeaders::Parameters::PercentageParameter<AUValue> feedback_;
  DSPHeaders::Parameters::PercentageParameter<AUValue> dryMix_;
  DSPHeaders::Parameters::PercentageParameter<AUValue> wetMix_;
  DSPHeaders::Parameters::BoolParameter negativeFeedback_;
  DSPHeaders::Parameters::BoolParameter odd90_;

  double samplesPerMillisecond_;
  double maxDelayMilliseconds_;

  std::vector<DSPHeaders::DelayBuffer<AUValue>> delayLines_;
  DSPHeaders::LFO<AUValue> lfo_;
  std::string name_;
  os_log_t log_;
};
