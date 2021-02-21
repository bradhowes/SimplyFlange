// Copyright © 2020 Brad Howes. All rights reserved.

import Foundation
import os

/**
 Address definitions for AUParameter settings.
 */
@objc public enum FilterParameterAddress: UInt64, CaseIterable {
    case depth = 0
    case rate
    case delay
    case feedback
    case dryMix
    case wetMix
}

private extension Array where Element == AUParameter {
    subscript(index: FilterParameterAddress) -> AUParameter { self[Int(index.rawValue)] }
}

/**
 Definitions for the runtime parameters of the filter.
 */
public final class AudioUnitParameters: NSObject {

    private let log = Logging.logger("FilterParameters")

    static public let maxDelayMilliseconds: AUValue = 15.0

    public let parameters: [AUParameter] = [
        AUParameterTree.createParameter(withIdentifier: "depth", name: "Depth", address: .depth,
                                        value: 100.0, min: 0.0, max: 100.0, unit: .percent),
        AUParameterTree.createParameter(withIdentifier: "rate", name: "Rate", address: .rate,
                                        value: 0.12, min: 0.0, max: 5.0, unit: .hertz),
        AUParameterTree.createParameter(withIdentifier: "delay", name: "Delay", address: .delay,
                                        value: 0.7, min: 0.0, max: AudioUnitParameters.maxDelayMilliseconds,
                                        unit: .milliseconds),
        AUParameterTree.createParameter(withIdentifier: "feedback", name: "Feedback", address: .feedback,
                                        value: 25.0, min: 0.0, max: 100.0, unit: .percent),
        AUParameterTree.createParameter(withIdentifier: "dry", name: "Dry", address: .dryMix,
                                        value: 50.0, min: 0.0, max: 100.0, unit: .percent),
        AUParameterTree.createParameter(withIdentifier: "wet", name: "Wet", address: .wetMix,
                                        value: 50.0, min: 0.0, max: 100.0, unit: .percent)
    ]

    /// AUParameterTree created with the parameter definitions for the audio unit
    public let parameterTree: AUParameterTree

    public var depth: AUParameter { parameters[.depth] }
    public var rate: AUParameter { parameters[.rate] }
    public var delay: AUParameter { parameters[.delay] }
    public var feedback: AUParameter { parameters[.feedback] }
    public var dryMix: AUParameter { parameters[.dryMix] }
    public var wetMix: AUParameter { parameters[.wetMix] }

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
            let formatted = self.formatValue(param.address.filterParameter, value: param.value)
            os_log(.debug, log: self.log, "parameter %d as string: %d %f %{public}s",
                   param.address, param.value, formatted)
            return formatted
        }
    }

    public subscript(address: FilterParameterAddress) -> AUParameter { parameters[address] }

    public func formatValue(_ address: FilterParameterAddress?, value: AUValue) -> String {
        switch address {
        case .depth, .feedback: return String(format: "%.2f%%", value)
        case .rate: return String(format: "%.2f Hz", value)
        case .delay: return String(format: "%.2f ms", value)
        case .dryMix, .wetMix: return String(format: "%.0f%%", value)
        default: return "?"
        }
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
    }
}
