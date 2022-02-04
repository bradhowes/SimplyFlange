// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Small Obj-C bridge between Swift and the C++ kernel classes. Handles AUParameter get/set requests by forwarding them to
 the kernel.
 */
@interface Bridge : NSObject

- (nonnull id)init:(NSString*)appExtensionName maxDelayMilliseconds:(AUValue)maxDelayMilliseconds;

/**
 Configure the kernel for new format and max frame in preparation to begin rendering

 @param inputFormat the current format of the input bus
 @param maxFramesToRender the max frames to expect in a render request
 @param maxDelayMilliseconds the max delay time in milliseconds
 */
- (void)startProcessing:(AVAudioFormat*)inputFormat maxFramesToRender:(AUAudioFrameCount)maxFramesToRender;

/**
 Stop processing, releasing any resources used to support rendering.
 */
- (void)stopProcessing;

/**
 Obtain a block to use for rendering with the kernel.

 @returns AUInternalRenderBlock instance
 */
- (AUInternalRenderBlock)internalRenderBlock;

/**
 Set the bypass state.

 @param state new bypass value
 */
- (void)setBypass:(BOOL)state;

- (void)set:(AUParameter *)parameter value:(AUValue)value;

- (AUValue)get:(AUParameter *)parameter;

@end

NS_ASSUME_NONNULL_END
