// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

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
   @param maxDelayMilliseconds the max number of milliseconds of audio samples to keep in delay buffer
   */
  Kernel(const std::string& name, double maxDelayMilliseconds)
  : super(os_log_create(name.c_str(), "Kernel")), maxDelay_{maxDelayMilliseconds}, delayLines_{}, lfo_()
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
    auto scale = depth_.norm() * delay_.milliseconds() * samplesPerMillisecond_;
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

  void initialize(int channelCount, double sampleRate) {
    samplesPerMillisecond_ = sampleRate / 1000.0;
    lfo_.initialize(sampleRate, 0.0);

    auto size = maxDelay_.milliseconds() * samplesPerMillisecond_ + 1;
    os_log_with_type(log_, OS_LOG_TYPE_INFO, "delayLine size: %f", size);
    delayLines_.clear();
    for (auto index = 0; index < channelCount; ++index) {
      delayLines_.emplace_back(size);
    }
  }

  void doParameterEvent(const AUParameterEvent& event) { setParameterValue(event.parameterAddress, event.value); }

  void doRendering(const std::vector<AUValue*>& ins, const std::vector<AUValue*>& outs, AUAudioFrameCount frameCount) {
    auto signedFeedback = negativeFeedback_ ? -feedback_.norm() : feedback_.norm();
    for (int channel = 0; channel < ins.size(); ++channel) {
      auto input{ins[channel]};
      auto output{outs[channel]};
      auto delayPos{delayPos_[(odd90_ && (channel & 1)) ? 1 : 0]};
      auto& delay{delayLines_[channel]};
      for (int frame = 0; frame < frameCount; ++frame) {
        auto inputSample = *input++;
        auto delayedSample = delay.read(*delayPos++);
        delay.write(inputSample + signedFeedback * delayedSample);
        *output++ = wetMix_.norm() * delayedSample + dryMix_.norm() * inputSample;
      }
    }
  }

  void doMIDIEvent(const AUMIDIEvent& midiEvent) {}

  PercentageParameter depth_;
  MillisecondsParameter delay_;
  PercentageParameter feedback_;
  PercentageParameter dryMix_;
  PercentageParameter wetMix_;
  BoolParameter negativeFeedback_;
  BoolParameter odd90_;

  MillisecondsParameter maxDelay_;
  double samplesPerMillisecond_;

  std::vector<DelayBuffer<AUValue>> delayLines_;
  LFO<double> lfo_;
  InputBuffer delayPos_;
};
