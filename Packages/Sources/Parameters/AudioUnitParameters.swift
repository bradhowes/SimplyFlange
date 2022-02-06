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
public final class AudioUnitParameters: NSObject, ParameterSource {

  private let log = Shared.logger("AudioUnitParameters")

  /// Array of AUParameter entities created from ParameterAddress value definitions.
  public let parameters: [AUParameter] = ParameterAddress.allCases.map { $0.parameterDefinition.parameter }

  /// Array of 2-tuple values that pair a factory preset name and its definition
  public let factoryPresetValues: [(name: String, preset: FilterPreset)] = [
    ("Flangie",
     .init(depth: 7, rate: 0.07, delay: 0.0, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90: 0)),
    ("Sweeper",
     .init(depth: 15, rate: 0.6, delay: 0.14, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90: 0)),
    ("Chorious",
     .init(depth: 20, rate: 0.3, delay: 0.15, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90:1)),
    ("Lord Tremolo",
     .init(depth: 5, rate: 8.0, delay: 0.0, feedback: 85, dry: 0, wet: 100, negativeFeedback: 0, odd90:0)),
    ("Wide Flangie",
     .init(depth: 100, rate: 0.14, delay: 0.72, feedback: 50, dry: 50, wet: 50, negativeFeedback: 0, odd90: 1)),
    ("Wide Sweeper",
     .init(depth: 100, rate: 0.14, delay: 1.51, feedback: 80, dry: 50, wet: 50, negativeFeedback: 0, odd90: 1)),
  ]

  /// Array of `AUAudioUnitPreset` for the factory presets.
  public var factoryPresets: [AUAudioUnitPreset] {
    factoryPresetValues.enumerated().map { .init(number: $0.0, name: $0.1.name ) }
  }

  /// Apply a factory preset -- user preset changes are handled by changing AUParameter values through the audio unit's
  /// `fullState` attribute.
  public func usePreset(_ preset: AUAudioUnitPreset) {
    if preset.number >= 0 {
      setValues(factoryPresetValues[preset.number].preset)
    }
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
  }

  /**
   Installs three closures in the tree based on the given parameter handler
   - one for providing values
   - one for accepting new values from other sources
   - and one for obtaining formatted string values

   - parameter parameterHandler the object to use to handle the AUParameterTree requests
   */
  public func setParameterHandler(_ parameterHandler: AUParameterHandler) {
    parameterTree.implementorValueObserver = { parameterHandler.set($0, value: $1) }
    parameterTree.implementorValueProvider = { parameterHandler.get($0) }
    parameterTree.implementorStringFromValueCallback = { param, value in
      let formatted = self.formatValue(ParameterAddress(rawValue: param.address), value: param.value)
      os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
             param.address, param.value, formatted)
      return formatted
    }
  }
}

extension AudioUnitParameters {

  private var missingParameter: AUParameter { fatalError() }

  public subscript(address: ParameterAddress) -> AUParameter {
    parameterTree.parameter(withAddress: address.parameterAddress) ?? missingParameter
  }

  public func valueFormatter(_ address: ParameterAddress) -> (AUValue) -> String {
    let unitName = self[address].unitName ?? ""

    let separator: String = {
      switch address {
      case .depth, .rate, .delay: return " "
      default: return ""
      }
    }()

    let format: String = formatting(address)

    return { value in String(format: format, value) + separator + unitName }
  }

  public func formatValue(_ address: ParameterAddress?, value: AUValue) -> String {
    guard let address = address else { return "?" }
    let format = formatting(address)
    return String(format: format, value)
  }

  /**
   Accept new values for the filter settings. Uses the AUParameterTree framework for communicating the changes to the
   AudioUnit.
   */
  public func setValues(_ preset: FilterPreset) {
    self.depth.value = preset.depth
    self.rate.value = preset.rate
    self.delay.value = preset.delay
    self.feedback.value = preset.feedback
    self.dryMix.value = preset.dry
    self.wetMix.value = preset.wet
    self.negativeFeedback.value = preset.negativeFeedback
    self.odd90.value = preset.odd90
  }
}

extension AudioUnitParameters {
  private func formatting(_ address: ParameterAddress) -> String {
    switch address {
    case .depth, .feedback: return "%.2f"
    case .rate: return "%.2f"
    case .delay: return "%.2f"
    case .dry, .wet, .negativeFeedback, .odd90: return "%.0f"
    default: return "?"
    }
  }
}
