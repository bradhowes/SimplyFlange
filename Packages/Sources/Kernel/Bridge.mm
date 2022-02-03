// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>

#import "C++/Kernel.hpp"
#import "Bridge.h"

@implementation Bridge {
  Kernel* kernel_;
  AUAudioFrameCount maxFramesToRender_;
}

- (instancetype)init:(NSString*)appExtensionName {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String));
    self->maxFramesToRender_ = 0;
  }
  return self;
}

- (void)startProcessing:(AVAudioFormat*)inputFormat
      maxFramesToRender:(AUAudioFrameCount)maxFramesToRender
   maxDelayMilliseconds:(AUValue)maxDelayMilliseconds{
  kernel_->startProcessing(inputFormat, maxFramesToRender, maxDelayMilliseconds);
  maxFramesToRender_ = maxFramesToRender;
}

- (void)stopProcessing {
  kernel_->stopProcessing();
}

- (AUInternalRenderBlock) renderBlock {
  auto& kernel = *kernel_;
  auto maxFramesToRender = maxFramesToRender_;
  NSInteger bus = 0;
  return ^AUAudioUnitStatus(AudioUnitRenderActionFlags* flags, const AudioTimeStamp* timestamp,
                            AUAudioFrameCount frameCount, NSInteger, AudioBufferList* output,
                            const AURenderEvent* realtimeEventListHead, AURenderPullInputBlock pullInputBlock) {
    // My reading of the flags is that they should all be zero on input for normal rendering.
    if (*flags != 0) return 0;
    if (frameCount > maxFramesToRender) return kAudioUnitErr_TooManyFramesToProcess;
    if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;
    return kernel.processAndRender(timestamp, frameCount, bus, output, realtimeEventListHead, pullInputBlock);
  };
}

- (void)setBypass:(BOOL)state {
  kernel_->setBypass(state);
}

// AUParameterHandler conformance

- (void)set:(AUParameter *)parameter value:(AUValue)value { kernel_->setParameterValue(parameter.address, value); }

- (AUValue)get:(AUParameter *)parameter { return kernel_->getParameterValue(parameter.address); }

@end
