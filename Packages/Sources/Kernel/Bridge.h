// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Protocol for entities that can respond to get/set requests in the AUParameterTree. The Adapter will conform to this
 protocol, but the C++ kernel will actually handle the requests.
 */
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
 Small Obj-C bridge between Swift and the C++ kernel classes. Handles AUParameter get/set requests by forwarding them to
 the kernel.
 */
@interface Bridge : NSObject <AUParameterHandler>

- (nonnull id)init:(NSString*)appExtensionName;

/**
 Configure the kernel for new format and max frame in preparation to begin rendering

 @param inputFormat the current format of the input bus
 @param maxFramesToRender the max frames to expect in a render request
 @param maxDelayMilliseconds the max delay time in milliseconds
 */
- (void)startProcessing:(AVAudioFormat*)inputFormat
      maxFramesToRender:(AUAudioFrameCount)maxFramesToRender
   maxDelayMilliseconds:(AUValue)maxDelayMilliseconds;

/**
 Stop processing, releasing any resources used to support rendering.
 */
- (void)stopProcessing;

/**
 Obtain a block to use for rendering with the kernel.

 @returns AUInternalRenderBlock instance
 */
- (AUInternalRenderBlock)renderBlock;

/**
 Set the bypass state.

 @param state new bypass value
 */
- (void)setBypass:(BOOL)state;

@end

NS_ASSUME_NONNULL_END
