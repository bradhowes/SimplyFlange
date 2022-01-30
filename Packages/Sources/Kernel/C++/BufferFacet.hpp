// Copyright © 2021 Brad Howes. All rights reserved.

#pragma once

#import <os/log.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

#import <vector>

/**
 Provides a simple std::vector view of an AudioBufferList.
 */
struct BufferFacet {
  BufferFacet() : bufferList_{nullptr}, pointers_{} {}
  
  void setBufferList(AudioBufferList* bufferList, AudioBufferList* inPlaceSource = nullptr) {
    bufferList_ = bufferList;
    if (bufferList->mBuffers[0].mData == nullptr) {
      assert(inPlaceSource != nullptr);
      for (auto channel = 0; channel < bufferList->mNumberBuffers; ++channel) {
        bufferList->mBuffers[channel].mData = inPlaceSource->mBuffers[channel].mData;
      }
    }
    
    size_t numBuffers = bufferList_->mNumberBuffers;
    pointers_.reserve(numBuffers);
    pointers_.clear();
    for (auto channel = 0; channel < numBuffers; ++channel) {
      pointers_.push_back(static_cast<AUValue*>(bufferList_->mBuffers[channel].mData));
    }
  }
  
  void setFrameCount(AUAudioFrameCount frameCount) {
    assert(bufferList_ != nullptr);
    UInt32 byteSize = frameCount * sizeof(AUValue);
    for (auto channel = 0; channel < bufferList_->mNumberBuffers; ++channel) {
      bufferList_->mBuffers[channel].mDataByteSize = byteSize;
    }
  }
  
  void setOffset(AUAudioFrameCount offset) {
    for (size_t channel = 0; channel < pointers_.size(); ++channel) {
      pointers_[channel] = static_cast<AUValue*>(bufferList_->mBuffers[channel].mData) + offset;
    }
  }
  
  void release() {
    bufferList_ = nullptr;
    pointers_.clear();
  }
  
  void copyInto(BufferFacet& destination, AUAudioFrameCount offset, AUAudioFrameCount frameCount) const {
    auto outputs = destination.bufferList_;
    for (auto channel = 0; channel < bufferList_->mNumberBuffers; ++channel) {
      if (bufferList_->mBuffers[channel].mData == outputs->mBuffers[channel].mData) {
        continue;
      }
      
      auto in = static_cast<AUValue*>(bufferList_->mBuffers[channel].mData) + offset;
      auto out = static_cast<AUValue*>(outputs->mBuffers[channel].mData) + offset;
      memcpy(out, in, frameCount * sizeof(AUValue));
    }
  }
  
  size_t channelCount() const { return pointers_.size(); }
  AUValue* operator[](size_t index) const { return pointers_[index]; }
  
  const std::vector<AUValue*>& V() const { return pointers_; }
  
private:
  AudioBufferList* bufferList_;
  std::vector<AUValue*> pointers_;
};
