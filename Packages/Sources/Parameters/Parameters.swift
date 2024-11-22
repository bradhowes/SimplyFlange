// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Foundation
import ParameterAddress
import os.log

private extension Array where Element == AUParameter {
  subscript(index: ParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class Parameters: NSObject, ParameterSource {

  private let log = Shared.logger("AudioUnitParameters")

  /// Array of AUParameter entities created from ParameterAddress value definitions.
  public let parameters: [AUParameter] = ParameterAddress.allCases.map { $0.parameterDefinition.parameter }

  /// Array of 2-tuple values that pair a factory preset name and its definition
  public let factoryPresetValues: [(name: String, configuration: Configuration)] = [
    ("Flangie",
     .init(delay: 0.00, depth: 14, rate: 0.07, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90: 0)),
    ("Sweeper",
     .init(delay: 0.14, depth: 30, rate: 0.60, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90: 0)),
    ("Chorious",
     .init(delay: 0.59, depth: 100, rate: 1.84, feedback: 0, dry: 50, wet: 50, negativeFeedback: 0, odd90: 1)),
    ("Squeaky Tremolo",
     .init(delay: 0.01, depth: 13, rate: 8.00, feedback: 90, dry: 0, wet: 100, negativeFeedback: 0, odd90: 0)),
    ("Wide Flangie",
     .init(delay: 0.60, depth: 100, rate: 0.14, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90: 1)),
    ("Wide Sweeper",
     .init(delay: 0.75, depth: 100, rate: 0.14, feedback: 80, dry: 50, wet: 100, negativeFeedback: 0, odd90: 1)),
  ]

  /// Array of `AUAudioUnitPreset` for the factory presets.
  public var factoryPresets: [AUAudioUnitPreset] {
    factoryPresetValues.enumerated().map { .init(number: $0.0, name: $0.1.name ) }
  }

  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree

  /// Obtain the parameter setting that determines how much variation in time there is when reading values from
  /// the delay buffer.
  public var depth: AUParameter { parameters[.depth] }
  /// Obtain the parameter setting that determines how fast the LFO operates
  public var rate: AUParameter { parameters[.rate] }
  /// Obtain the parameter setting that determines the minimum delay applied incoming samples. The actual delay value is
  /// this value plus the `depth` times the current LFO value.
  public var delay: AUParameter { parameters[.delay] }
  /// Obtain the parameter setting that determines how much of the processed signal is added to the 
  public var feedback: AUParameter { parameters[.feedback] }
  /// Obtain the `depth` parameter setting
  public var dryMix: AUParameter { parameters[.dry] }
  /// Obtain the `depth` parameter setting
  public var wetMix: AUParameter { parameters[.wet] }
  /// Obtain the `depth` parameter setting
  public var negativeFeedback: AUParameter { parameters[.negativeFeedback] }
  /// Obtain the `depth` parameter setting
  public var odd90: AUParameter { parameters[.odd90] }

  /**
   Create a new AUParameterTree for the defined filter parameters.
   */
  override public init() {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
    installParameterValueFormatter()
  }
}

extension Parameters {

  private var missingParameter: AUParameter { fatalError() }

  /// Apply a factory preset -- user preset changes are handled by changing AUParameter values through the audio unit's
  /// `fullState` attribute.
  public func useFactoryPreset(_ preset: AUAudioUnitPreset) {
    if preset.number >= 0 {
      setValues(factoryPresetValues[preset.number].configuration)
    }
  }

  /**
   Obtain the AUParameter for a given parameter address

   - parameter address: the address of the parameter to obtain
   - returns: the AUParameter instance
   */
  public subscript(address: ParameterAddress) -> AUParameter {
    parameterTree.parameter(withAddress: address.parameterAddress) ?? missingParameter
  }

  private func installParameterValueFormatter() {
    parameterTree.implementorStringFromValueCallback = { param, valuePtr in
      let value: AUValue
      if let valuePtr = valuePtr {
        value = valuePtr.pointee
      } else {
        value = param.value
      }
      return param.displayValueFormatter(value)
    }
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  public func setValues(_ configuration: Configuration) {
    depth.value = configuration.depth
    rate.value = configuration.rate
    delay.value = configuration.delay
    feedback.value = configuration.feedback
    dryMix.value = configuration.dry
    wetMix.value = configuration.wet
    negativeFeedback.value = configuration.negativeFeedback
    odd90.value = configuration.odd90
  }
}

extension AUParameter: @retroactive AUParameterFormatting {

  public var unitSeparator: String {
    switch self.parameterAddress {
    case .depth, .feedback, .dry, .wet: return ""
    default: return " "
    }
  }

  public var suffix: String { makeFormattingSuffix(from: unitName) }

  public var stringFormatForDisplayValue: String {
    switch self.parameterAddress {
    case .depth, .feedback, .dry, .wet: return "%.0f"
    default: return "%.2f"
    }
  }
}
