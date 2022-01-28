// Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support
import Foundation
import os

/**
 Address definitions for AUParameter settings.
 */
@objc public enum FilterParameterAddress: UInt64, CaseIterable, ParameterAddressProvider {
  public var parameterAddress: AUParameterAddress { rawValue }

  case depth = 0
  case rate
  case delay
  case feedback
  case dryMix
  case wetMix
  case negativeFeedback
  case odd90
}

private extension Array where Element == AUParameter {
  subscript(index: FilterParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject {
  
  private let log = Logging.logger("FilterParameters")
  
  static public let maxDelayMilliseconds: AUValue = 50.0
  
  public let parameters: [AUParameter] = [
    AUParameterTree.createParameter(withIdentifier: "depth", name: "Depth", address: FilterParameterAddress.depth,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "rate", name: "Rate", address: FilterParameterAddress.rate,
                                    min: 0.01, max: 20.0, unit: .hertz),
    AUParameterTree.createParameter(withIdentifier: "delay", name: "Delay", address: FilterParameterAddress.delay,
                                    min: 1.0, max: AudioUnitParameters.maxDelayMilliseconds, unit: .milliseconds),
    AUParameterTree.createParameter(withIdentifier: "feedback", name: "Feedback", address: FilterParameterAddress.feedback,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "dry", name: "Dry", address: FilterParameterAddress.dryMix,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "wet", name: "Wet", address: FilterParameterAddress.wetMix,
                                    min: 0.0, max: 100.0, unit: .percent),
    AUParameterTree.createParameter(withIdentifier: "-feedback", name: "-Feedback", address: FilterParameterAddress.negativeFeedback,
                                    min: 0.0, max: 1.0, unit: .boolean),
    AUParameterTree.createParameter(withIdentifier: "odd90", name: "odd90", address: FilterParameterAddress.odd90, min: 0.0, max: 1.0,
                                    unit: .boolean)
  ]
  
  public let factoryPresetValues: [(name: String, preset: FilterPreset)] = [
    ("Flangie", FilterPreset(depth: 100, rate: 0.14, delay: 1.10, feedback: 20, dryMix: 50, wetMix: 50,
                             negativeFeedback: 0, odd90: 0)),
    ("Sweeper", FilterPreset(depth: 100, rate: 0.14, delay: 1.51, feedback: 80, dryMix: 50, wetMix: 50,
                             negativeFeedback: 0, odd90: 0)),
    ("Chorious", FilterPreset(depth: 64, rate: 1.8, delay: 3.23, feedback: 0, dryMix: 50, wetMix: 50,
                              negativeFeedback: 0, odd90:1)),
    ("Lord Tremolo", FilterPreset(depth: 100, rate: 8.6, delay: 0.07, feedback: 90, dryMix: 0, wetMix: 100,
                                  negativeFeedback: 0, odd90:0)),
    ("Wide Flangie", FilterPreset(depth: 100, rate: 0.14, delay: 0.72, feedback: 50, dryMix: 50, wetMix: 50,
                                  negativeFeedback: 0, odd90: 1)),
    ("Wide Sweeper", FilterPreset(depth: 100, rate: 0.14, delay: 1.51, feedback: 80, dryMix: 50, wetMix: 50,
                                  negativeFeedback: 0, odd90: 1)),
  ]
  
  
  /// AUParameterTree created with the parameter definitions for the audio unit
  public let parameterTree: AUParameterTree
  
  public var depth: AUParameter { parameters[.depth] }
  public var rate: AUParameter { parameters[.rate] }
  public var delay: AUParameter { parameters[.delay] }
  public var feedback: AUParameter { parameters[.feedback] }
  public var dryMix: AUParameter { parameters[.dryMix] }
  public var wetMix: AUParameter { parameters[.wetMix] }
  public var negativeFeedback: AUParameter { parameters[.negativeFeedback] }
  public var odd90: AUParameter { parameters[.odd90] }
  
  /**
   Create a new AUParameterTree for the defined filter parameters.
   
   Installs three closures in the tree:
   - one for providing values
   - one for accepting new values from other sources
   - and one for obtaining formatted string values
   
   - parameter parameterHandler the object to use to handle the AUParameterTree requests
   */
  init(parameterHandler: AUParameterHandler) {
    parameterTree = AUParameterTree.createTree(withChildren: parameters)
    super.init()
    
    parameterTree.implementorValueObserver = { parameterHandler.set($0, value: $1) }
    parameterTree.implementorValueProvider = { parameterHandler.get($0) }
    parameterTree.implementorStringFromValueCallback = { param, value in
      let formatted = self.formatValue(FilterParameterAddress(rawValue: param.address), value: param.value)
      os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
             param.address, param.value, formatted)
      return formatted
    }
  }
}

extension AudioUnitParameters {
  
  public subscript(address: FilterParameterAddress) -> AUParameter { parameters[address] }
  
  public func valueFormatter(_ address: FilterParameterAddress) -> (AUValue) -> String {
    let unitName = self[address].unitName ?? ""
    
    let separator: String = {
      switch address {
      case .rate, .delay: return " "
      default: return ""
      }
    }()
    
    let format: String = formatting(address)
    
    return { value in String(format: format, value) + separator + unitName }
  }
  
  public func formatValue(_ address: FilterParameterAddress?, value: AUValue) -> String {
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
    self.dryMix.value = preset.dryMix
    self.wetMix.value = preset.wetMix
    self.negativeFeedback.value = preset.negativeFeedback
    self.odd90.value = preset.odd90
  }
}

extension AudioUnitParameters {
  private func formatting(_ address: FilterParameterAddress) -> String {
    switch address {
    case .depth, .feedback: return "%.2f"
    case .rate: return "%.2f"
    case .delay: return "%.2f"
    case .dryMix, .wetMix, .negativeFeedback, .odd90: return "%.0f"
    default: return "?"
    }
  }
}
