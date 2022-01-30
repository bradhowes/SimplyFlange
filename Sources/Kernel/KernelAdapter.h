// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Address definitions for the AUParameter settings of the filter. Available in Swift as `FilterParameterAddress` enum.
 NOTE: changes made here must also be reflected in the `allCases` property created in the `Parameters.swift` file of the
 `Parameters` library.
 */
typedef NS_ENUM(UInt64, ParameterAddress) {
  ParameterAddress_Depth = 0,
  ParameterAddress_Rate,
  ParameterAddress_Delay,
  ParameterAddress_Feedback,
  ParameterAddress_DryMix,
  ParameterAddress_WetMix,
  ParameterAddress_NegativeFeedback,
  ParameterAddress_Odd90
};

@protocol AUParameterHandler

/**
 Set an AUParameter to a new value
 */
- (void)set:(AUParameter *)parameter value:(AUValue)value;

/**
 Get the current value of an AUParameter
 */
- (AUValue)get:(AUParameter *)parameter;

@end

/**
 Small Obj-C wrapper around the FilterKernel C++ class. Handles AUParameter get/set requests by forwarding them to
 the kernel.
 */
@interface SimplyFlangeKernelAdapter : NSObject <AUParameterHandler>

- (nonnull id)init:(NSString*)appExtensionName maxDelayMilliseconds:(float)maxDelay;

/**
 Configure the kernel for new format and max frame in preparation to begin rendering
 
 @param inputFormat the current format of the input bus
 @param maxFramesToRender the max frames to expect in a render request
 */
- (void)startProcessing:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender;

/**
 Stop processing, releasing any resources used to support rendering.
 */
- (void)stopProcessing;

/**
 Process upstream input
 
 @param timestamp the timestamp for the rendering
 @param frameCount the number of frames to render
 @param output the buffer to hold the rendered samples
 @param realtimeEventListHead the first AURenderEvent to process (may be null)
 @param pullInputBlock the closure to invoke to fetch upstream samples
 */
- (AUAudioUnitStatus)process:(AudioTimeStamp*)timestamp
                  frameCount:(UInt32)frameCount
                      output:(AudioBufferList*)output
                      events:(nullable AURenderEvent*)realtimeEventListHead
              pullInputBlock:(AURenderPullInputBlock)pullInputBlock;

/**
 Set the bypass state.
 
 @param state new bypass value
 */
- (void)setBypass:(BOOL)state;

@end

NS_ASSUME_NONNULL_END
