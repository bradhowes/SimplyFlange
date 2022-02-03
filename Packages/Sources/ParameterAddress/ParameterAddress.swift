import AudioUnit.AUParameters
import AUv3Support

/**
 These are the unique addresses for the runtime parameters used by the audio unit.
 */
@objc public enum ParameterAddress: UInt64, CaseIterable {
  case depth = 0
  case rate
  case delay
  case feedback
  case dry
  case wet
  case negativeFeedback
  case odd90
};

extension ParameterAddress {

  /// Obtain a ParameterDefinition for a parameter address enum.
  public var parameterDefinition: ParameterDefinition {
    switch self {
    case .depth: return .defPercent("depth", localized: "Depth", address: ParameterAddress.depth)
    case .rate: return .defFloat("rate", localized: "Rate", address: ParameterAddress.rate,
                                 range: 0.01...20.0, unit: .hertz)
    case .delay: return .defFloat("delay", localized: "Delay", address: ParameterAddress.delay,
                                  range: 1.0...50.0, unit: .milliseconds)
    case .feedback: return .defPercent("feedback", localized: "Feedback", address: ParameterAddress.feedback)
    case .dry: return .defPercent("dry", localized: "Dry", address: ParameterAddress.dry)
    case .wet: return .defPercent("wet", localized: "Wet", address: ParameterAddress.wet)
    case .negativeFeedback: return .defBool("-feedback", localized: "-Feedback",
                                            address: ParameterAddress.negativeFeedback)
    case .odd90: return .defBool("odd90", localized: "Odd 90°", address: ParameterAddress.odd90)
    }
  }
}

/// Allow enum values to serve as AUParameterAddress values.
extension ParameterAddress: ParameterAddressProvider {
  public var parameterAddress: AUParameterAddress { UInt64(self.rawValue) }
}
