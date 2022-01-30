// Copyright © 2021 Brad Howes. All rights reserved.

import AudioUnit

public struct FilterPreset {
  public let depth: AUValue
  public let rate: AUValue
  public let delay: AUValue
  public let feedback: AUValue
  public let dryMix: AUValue
  public let wetMix: AUValue
  public let negativeFeedback: AUValue
  public let odd90: AUValue

  public init(depth: AUValue, rate: AUValue, delay: AUValue, feedback: AUValue, dryMix: AUValue, wetMix: AUValue,
              negativeFeedback: AUValue, odd90: AUValue) {
    self.depth = depth
    self.rate = rate
    self.delay = delay
    self.feedback = feedback
    self.dryMix = dryMix
    self.wetMix = wetMix
    self.negativeFeedback = negativeFeedback
    self.odd90 = odd90
  }
}
