// Copyright © 2022 Brad Howes. All rights reserved.

#import <CoreAudioKit/CoreAudioKit.h>

#import "C++/Kernel.hpp"
#import "Adapter.h"

@implementation Adapter {
  Kernel* kernel_;
}

- (instancetype)init:(NSString*)appExtensionName maxDelayMilliseconds:(float)maxDelay {
  if (self = [super init]) {
    self->kernel_ = new Kernel(std::string(appExtensionName.UTF8String), maxDelay);
  }
  return self;
}

- (void)startProcessing:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender {
  kernel_->startProcessing(inputFormat, maxFramesToRender);
}

- (void)stopProcessing {
  kernel_->stopProcessing();
}

- (AUInternalRenderBlock) renderBlock {
  // This is probably not necessary...
  auto& kernel = *kernel_;
  NSInteger bus = 0;
  return ^(AudioUnitRenderActionFlags * _Nonnull flags, const AudioTimeStamp * _Nonnull timestamp,
           AUAudioFrameCount frameCount, NSInteger, AudioBufferList * _Nonnull output,
           const AURenderEvent * _Nullable realtimeEventListHead,
          AURenderPullInputBlock  _Nullable __unsafe_unretained pullInputBlock) {
    // My reading of the flags is that they should all be zero on input for normal rendering.
    if (*flags != 0) return 0;
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
