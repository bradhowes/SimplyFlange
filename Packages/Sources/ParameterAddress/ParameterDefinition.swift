import AudioUnit

public struct ParameterDefinition {
  let identifier: String
  let localized: String
  let address: ParameterAddress
  let range: ClosedRange<AUValue>
  let unit: AudioUnitParameterUnit
  let unitName: String?
  let ramping: Bool

  public init(_ identifier: String, localized: String, address: ParameterAddress, range: ClosedRange<AUValue>,
              unit: AudioUnitParameterUnit, unitName: String?, ramping: Bool) {
    self.identifier = identifier
    self.localized = localized
    self.address = address
    self.range = range
    self.unit = unit
    self.unitName = unitName
    self.ramping = ramping
  }

  public static func defBool(_ identifier: String, localized: String, address: ParameterAddress) -> ParameterDefinition {
    .init(identifier, localized: localized, address: address, range: 0.0...1.0, unit: .boolean, unitName: nil,
          ramping: false)
  }

  public static func defFloat(_ identifier: String, localized: String, address: ParameterAddress,
                              range: ClosedRange<AUValue>, unit: AudioUnitParameterUnit, unitName: String? = nil,
                              ramping: Bool = true) -> ParameterDefinition {
    .init(identifier, localized: localized, address: address, range: range, unit: unit, unitName: unitName,
          ramping: ramping)
  }

  public static func defPercent(_ identifier: String, localized: String, address: ParameterAddress) -> ParameterDefinition {
    .init(identifier, localized: localized, address: address, range: 0.0...100.0, unit: .percent, unitName: nil,
          ramping: true)
  }

  public var parameter: AUParameter {
    var flags: AudioUnitParameterOptions = [.flag_IsReadable, .flag_IsWritable]
    if ramping {
      flags.insert(.flag_CanRamp)
    }
    return AUParameterTree.createParameter(withIdentifier: identifier, name: localized,
                                           address: address.parameterAddress, min: range.lowerBound,
                                           max: range.upperBound, unit: unit, unitName: unitName,
                                           flags: flags, valueStrings: nil, dependentParameters: nil)
  }
}

