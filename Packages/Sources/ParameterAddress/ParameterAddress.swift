import Foundation

/**
 These are the unique addresses for the runtime parameters used by the audio unit.
 */
@objc public enum ParameterAddress: UInt64, CaseIterable {
  case depth = 0
  case rate
  case delay
  case feedback
  case dryMix
  case wetMix
  case negativeFeedback
  case odd90
};

public extension ParameterAddress {

  // NOTE: according to Apple, these values should never change across releases.
  var identifier: String {
    switch self {
    case .depth: return "depth"
    case .rate: return "rate"
    case .delay: return "delay"
    case .feedback: return "feedback"
    case .dryMix: return "dry"
    case .wetMix: return "wet"
    case .negativeFeedback: return "-feedback"
    case .odd90: return "odd90"
    @unknown default: fatalError()
    }
  }

  // NOTE: these should be localized as they could be displayed to users
  var displayName: String {
    switch self {
    case .depth: return "Depth"
    case .rate: return "Rate"
    case .delay: return "Delay"
    case .feedback: return "Feedback"
    case .dryMix: return "Dry"
    case .wetMix: return "Wet"
    case .negativeFeedback: return "-Feedback"
    case .odd90: return "Odd 90°"
    @unknown default: fatalError()
    }
  }
}
