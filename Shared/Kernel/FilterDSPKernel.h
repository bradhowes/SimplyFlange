// Changes: Copyright © 2020 Brad Howes. All rights reserved.
// Original: See LICENSE folder for this sample’s licensing information.

#pragma once

#import <AVFoundation/AVFoundation.h>

#import "DelayBuffer.h"
#import "KernelEventProcessor.h"

#import "SimplyFlangerFilterFramework/SimplyFlangerFilterFramework-Swift.h"

class FilterDSPKernel : public KernelEventProcessor<FilterDSPKernel> {
public:
    using super = KernelEventProcessor<FilterDSPKernel>;
    friend super;

    FilterDSPKernel(std::string const& name, float maxDelayMilliseconds)
    :
    super(os_log_create(name.c_str(), "FilterDSPKernel")),
    maxDelayMilliseconds_{maxDelayMilliseconds},
    delayLines_{}
    {}

    /**
     Update kernel and buffers to support the given format and channel count
     */
    void startProcessing(AVAudioFormat* format, AUAudioFrameCount maxFramesToRender) {
        super::startProcessing(format, maxFramesToRender);
        initialize(format.channelCount, format.sampleRate);
    }

    void initialize(int channelCount, float sampleRate) {
        samplesPerMillisecond_ = sampleRate / 1000.0;
        delayInSamples_ = delay_ * samplesPerMillisecond_;

        auto size = maxDelayMilliseconds_ * samplesPerMillisecond_ + 1;
        os_log_with_type(log_, OS_LOG_TYPE_INFO, "delayLine size: %f delayInSamples: %f", size, delayInSamples_);
        delayLines_.clear();
        for (int index = 0; index < channelCount; ++index)
            delayLines_.emplace_back(size);
    }

    void stopProcessing() { super::stopProcessing(); }

    void setParameterValue(AUParameterAddress address, AUValue value) {
        switch (address) {
            case FilterParameterAddressDepth:
                value = value / 100.0;
                if (value == depth_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "depth - %f", value);
                depth_ = value;
                break;
            case FilterParameterAddressRate:
                if (value == rate_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "rate - %f", value);
                rate_ = value;
                break;
            case FilterParameterAddressDelay:
                if (value == delay_) return;
                delay_ = value;
                delayInSamples_ = samplesPerMillisecond_ * value;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "delay - %f  delayInSamples: %f", value, delayInSamples_);
                break;
            case FilterParameterAddressFeedback:
                value = value / 100.0;
                if (value == feedback_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "feedback - %f", value);
                feedback_ = value;
                break;
            case FilterParameterAddressWetDryMix:
                value = value / 100.0;
                if (value == wetDryMix_) return;
                os_log_with_type(log_, OS_LOG_TYPE_INFO, "wetDryMix - %f", value);
                wetDryMix_ = value;
                break;
        }
    }

    AUValue getParameterValue(AUParameterAddress address) const {
        switch (address) {
            case FilterParameterAddressDepth: return depth_ * 100.0;
            case FilterParameterAddressRate: return rate_;
            case FilterParameterAddressDelay: return delay_;
            case FilterParameterAddressFeedback: return feedback_ * 100.0;
            case FilterParameterAddressWetDryMix: return wetDryMix_ * 100.0;
        }
        return 0.0;
    }

    float depth() const { return depth_; }
    float rate() const { return rate_; }
    float delay() const { return delay_; }
    float feedback() const { return feedback_; }
    float wetDryMix() const { return wetDryMix_; }

private:

    void doParameterEvent(AUParameterEvent const& event) { setParameterValue(event.parameterAddress, event.value); }

    void doRendering(std::vector<float const*> ins, std::vector<float*> outs, AUAudioFrameCount frameCount) {
        os_log_with_type(log_, OS_LOG_TYPE_DEBUG, "delay: %f feedback: %f mix: %f delayInSamples: %f",
                         delay_, feedback_, wetDryMix_, delayInSamples_);
        for (int channel = 0; channel < ins.size(); ++channel) {
            auto input = ins[channel];
            auto& delayLine = delayLines_[channel];
            auto output = outs[channel];
            for (int index = 0; index < frameCount; ++index) {
                auto inputSample = *input++;
                auto delayedSample = delayLine.read(delayInSamples_);
                delayLine.write(inputSample + feedback_ * delayedSample);
                *output++ = wetDryMix_ * delayedSample + (1.0 - wetDryMix_) * inputSample;
            }
        }
    }

    void doMIDIEvent(AUMIDIEvent const& midiEvent) {}

    float maxDelayMilliseconds_;
    float samplesPerMillisecond_;
    float depth_;
    float rate_;
    float delay_;
    float delayInSamples_;
    float feedback_;
    float wetDryMix_;

    std::vector<DelayBuffer<float>> delayLines_;
};
