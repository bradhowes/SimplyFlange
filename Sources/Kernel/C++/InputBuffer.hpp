// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <os/log.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#import "BufferFacet.hpp"

/**
 Maintains a buffer of PCM samples which is used to save samples from an upstream node.
 */
struct InputBuffer {
  
  /**
   Set the format of the buffer to use.
   
   @param format the format of the samples
   @param maxFrames the maximum number of frames to be found in the upstream output
   */
  void allocateBuffers(AVAudioFormat* format, AUAudioFrameCount maxFrames)
  {
    maxFramesToRender_ = maxFrames;
    buffer_ = [[AVAudioPCMBuffer alloc] initWithPCMFormat: format frameCapacity: maxFrames];
    mutableAudioBufferList_ = buffer_.mutableAudioBufferList;
    bufferFacet_.setBufferList(mutableAudioBufferList_);
  }
  
  /**
   Forget any allocated buffer.
   */
  void releaseBuffers()
  {
    buffer_ = nullptr;
    mutableAudioBufferList_ = nullptr;
    bufferFacet_.release();
  }
  
  /**
   Obtain samples from an upstream node. Output is stored in internal buffer.
   
   @param actionFlags render flags from the host
   @param timestamp the current transport time of the samples
   @param frameCount the number of frames to process
   @param inputBusNumber the bus to pull from
   @param pullInputBlock the function to call to do the pulling
   */
  AUAudioUnitStatus pullInput(AudioUnitRenderActionFlags* actionFlags, AudioTimeStamp const* timestamp,
                              AVAudioFrameCount frameCount, NSInteger inputBusNumber,
                              AURenderPullInputBlock pullInputBlock)
  {
    if (pullInputBlock == nullptr) return kAudioUnitErr_NoConnection;
    prepareBufferList(frameCount);
    return pullInputBlock(actionFlags, timestamp, frameCount, inputBusNumber, mutableAudioBufferList_);
  }
  
  /**
   Update the input buffer to reflect current format.
   
   @param frameCount the number of frames to expect to place in the buffer
   */
  void prepareBufferList(AVAudioFrameCount frameCount)
  {
    UInt32 byteSize = frameCount * sizeof(AUValue);
    for (auto channel = 0; channel < mutableAudioBufferList_->mNumberBuffers; ++channel) {
      mutableAudioBufferList_->mBuffers[channel].mDataByteSize = byteSize;
    }
  }

  AUAudioFrameCount size() const { return maxFramesToRender_; }

  AudioBufferList* mutableAudioBufferList() const { return mutableAudioBufferList_; }
  
  BufferFacet& bufferFacet() { return bufferFacet_; }
  
  size_t channelCount() const { return bufferFacet_.channelCount(); }
  AUValue* operator[](size_t index) const { return bufferFacet_[index]; }
  
private:
  os_log_t logger_ = os_log_create("SimplyFlange", "BufferedInputBus");
  AUAudioFrameCount maxFramesToRender_ = 0;
  AVAudioPCMBuffer* buffer_ = nullptr;
  AudioBufferList* mutableAudioBufferList_ = nullptr;
  BufferFacet bufferFacet_;
};
