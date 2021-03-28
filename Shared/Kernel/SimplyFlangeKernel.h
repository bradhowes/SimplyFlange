// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <string>
#import <AVFoundation/AVFoundation.h>

#import "DelayBuffer.h"
#import "SimplyFlangeFramework/SimplyFlangeFramework-Swift.h"
#import "KernelEventProcessor.h"
#import "LFO.h"

class SimplyFlangeKernel : public KernelEventProcessor<SimplyFlangeKernel> {
public:
    using super = KernelEventProcessor<SimplyFlangeKernel>;
    friend super;

    SimplyFlangeKernel(const std::string& name, double maxDelayMilliseconds)
    : super(os_log_create(name.c_str(), "SimplyFlangeKernel")), maxDelayMilliseconds_{maxDelayMilliseconds},
    delayLines_{}, lfo_()
    {
        lfo_.setWaveform(LFOWaveform::triangle);
    }

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
        super::startProcessing(format, maxFramesToRender);
        initialize(format.channelCount, format.sampleRate);
        delayPos_.allocateBuffers(format, maxFramesToRender);
    }

    void initialize(int channelCount, double sampleRate) {
        samplesPerMillisecond_ = sampleRate / 1000.0;
        delayInSamples_ = delay_ * samplesPerMillisecond_;
        lfo_.initialize(sampleRate, rate_);

        auto size = maxDelayMilliseconds_ * samplesPerMillisecond_ + 1;
        os_log_with_type(log_, OS_LOG_TYPE_INFO, "delayLine size: %f delayInSamples: %f", size, delayInSamples_);
        delayLines_.clear();
        for (int index = 0; index < channelCount; ++index)
            delayLines_.emplace_back(size);
    }

    void prepareToRender(AUAudioFrameCount frameCount) {

        // Generate all delay position values necessary to render `frameCount` samples.
        auto scale = depth_ / 2.0 * delayInSamples_;
        auto state = lfo_.saveState();
        auto buffer = delayPos_[0];
        for (auto index = 0; index < frameCount; ++index) {
            *buffer++ = lfo_.valueAndIncrement() * scale + delayInSamples_;
        }

        if (odd90_) {
            lfo_.restoreState(state);
            buffer = delayPos_[1];
            for (auto index = 0; index < frameCount; ++index) {
                *buffer++ = lfo_.quadPhaseValueAndIncrement() * scale + delayInSamples_;
            }
        }
    }

    void stopProcessing() { super::stopProcessing(); }

    void setParameterValue(AUParameterAddress address, AUValue value) {
        switch (address) {
            case FilterParameterAddressDepth:
                depth_ = value / 100.0;
                break;
            case FilterParameterAddressRate:
                if (value == rate_) return;
                rate_ = value;
                lfo_.setFrequency(rate_);
                break;
            case FilterParameterAddressDelay:
                delay_ = value;
                delayInSamples_ = samplesPerMillisecond_ * value;
                break;
            case FilterParameterAddressFeedback:
                feedback_ = value / 100.0;
                break;
            case FilterParameterAddressDryMix:
                dryMix_ = value / 100.0;
                break;
            case FilterParameterAddressWetMix:
                wetMix_ = value / 100.0;
                break;
            case FilterParameterAddressNegativeFeedback:
                negativeFeedback_ = value > 0 ? true : false;
                break;
            case FilterParameterAddressOdd90:
                odd90_ = value > 0 ? true : false;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const {
        switch (address) {
            case FilterParameterAddressDepth: return depth_ * 100.0;
            case FilterParameterAddressRate: return rate_;
            case FilterParameterAddressDelay: return delay_;
            case FilterParameterAddressFeedback: return feedback_ * 100.0;
            case FilterParameterAddressDryMix: return dryMix_ * 100.0;
            case FilterParameterAddressWetMix: return wetMix_ * 100.0;
            case FilterParameterAddressNegativeFeedback: return negativeFeedback_ ? 1.0 : 0.0;
            case FilterParameterAddressOdd90: return odd90_ ? 1.0 : 0.0;
        }
        return 0.0;
    }

private:

    void doParameterEvent(const AUParameterEvent& event) { setParameterValue(event.parameterAddress, event.value); }

    void doRendering(const std::vector<AUValue*>& ins, const std::vector<AUValue*>& outs, AUAudioFrameCount frameCount)
    {
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

    double depth_; // NOTE: this ranges from 0.0 - 0.5 to absorb a / 2 operation in the delayPos calculation
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
