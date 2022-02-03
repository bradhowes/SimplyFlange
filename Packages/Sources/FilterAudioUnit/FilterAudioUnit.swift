// Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support
import AudioToolbox
import AVFoundation
import CoreAudioKit
import Parameters
import Kernel
import os

/// Protocol for delegates that handle view configuration. The FilterAudioUnit has no concern for this stuff.
public protocol AudioUnitViewConfigurationManager: AnyObject {

  /**
   Request from the AU host for what view configurations are acceptable to use when showing the view for this effect.

   - parameter available: array of available configurations
   - returns: set of indices into `available` that are acceptable to use
   */
  func supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet

  /**
   Request from the AU host for the effect to use a specific view configuration.

   - parameter viewConfiguration: the configuration to use
   */
  func selectViewConfiguration(_ viewConfiguration: AUAudioUnitViewConfiguration)
}

/**
 Derivation of AUAudioUnit that provides a Swift container for the C++ Kernel (by way of the Obj-C
 Bridge adapter). Also provides for factory presets and user preset management. This basically a generic container for
 audio filtering as all of the elements specific to a particular filter/effect are found elsewhere.

 The actual filtering logic resides in the Kernel C++ code.
 */
public final class FilterAudioUnit: AUAudioUnit {
  private let log = Shared.logger("FilterAudioUnit")

  /// Name of the component
  // public static let componentName = Bundle(for: FilterAudioUnit.self).auComponentName

  public enum Failure: Swift.Error {
    case statusError(OSStatus)
    case unableToInitialize(String)
  }

  /// The signal processing kernel that performs the rendering of audio samples
  private var kernel: Bridge = Bridge(Bundle.main.auBaseName)
  /// Runtime parameter definitions for the audio unit
  public lazy var parameters: AudioUnitParameters = .init(parameterHandler: kernel)
  /// The associated view controller for the audio unit that shows the controls
  public weak var viewConfigurationManager: AudioUnitViewConfigurationManager?
  /// Support one input bus
  override public var inputBusses: AUAudioUnitBusArray { _inputBusses }
  /// Support one output bus
  override public var outputBusses: AUAudioUnitBusArray { _outputBusses }
  /// Parameter tree containing filter parameter values
  override public var parameterTree: AUParameterTree? {
    get { parameters.parameterTree }
    set { fatalError("attempted to set new parameterTree") }
  }
  
  private var factoryPresetValues: [(name: String, preset: FilterPreset)] { parameters.factoryPresetValues };
  private lazy var _factoryPresets: [AUAudioUnitPreset] = factoryPresetValues.enumerated().map {
    .init(number: $0, name: $1.name)
  }
  
  /// Factory presets for the filter
  override public var factoryPresets: [AUAudioUnitPreset] { _factoryPresets }
  /// Announce support for user presets as well
  override public var supportsUserPresets: Bool { true }
  /// Preset get/set
  override public var currentPreset: AUAudioUnitPreset? {
    get {
      os_log(.info, log: log, "get currentPreset - %{public}s", _currentPreset.descriptionOrNil)
      return _currentPreset
    }
    set {
      os_log(.info, log: log, "set currentPreset - %{public}s", newValue.descriptionOrNil)
      guard let preset = newValue else {
        _currentPreset = nil
        return
      }
      
      if preset.number >= 0 {
        os_log(.info, log: log, "factoryPreset %d", preset.number)
        let settings = factoryPresetValues[preset.number]
        _currentPreset = preset
        os_log(.info, log: log, "updating parameters")
        parameters.setValues(settings.preset)
      }
      else {
        os_log(.info, log: log, "userPreset %d", preset.number)
        if let state = try? presetState(for: preset) {
          os_log(.info, log: log, "state: %{public}s", state.debugDescription)
          fullState = state
          _currentPreset = preset
        }
      }
    }
  }
  
  override public var fullState: [String : Any]? {
    get {
      os_log(.info, log: log, "fullState GET")

      // The AUAudioUnit class will provide the current settings from the AUParameterTree. We only add any preset info.
      var value = super.fullState ?? [String: Any]()
      if let preset = _currentPreset {
        value[kAUPresetNameKey] = preset.name
        value[kAUPresetNumberKey] = preset.number
      }
      os_log(.info, log: log, "value: %{public}s", value.description)
      return value
    }
    set {
      os_log(.info, log: log, "fullState SET")
      os_log(.info, log: log, "value: %{public}s", newValue.descriptionOrNil)
      super.fullState = newValue
      // Restore current preset if there was one.
      if let newValue = newValue,
         let name = newValue[kAUPresetNameKey] as? String,
         let number = newValue[kAUPresetNumberKey] as? NSNumber {
        os_log(.info, log: log, "name %{public}s number %d", name, number.intValue)
        _currentPreset = AUAudioUnitPreset(number: number.intValue, name: name)
      }
    }
  }
  
  override public var shouldBypassEffect: Bool { didSet { kernel.setBypass(shouldBypassEffect); }}

  // We don't have any additional state beyond what is in `fullState`.
  // override public var fullStateForDocument: [String : Any]?

  /// Announce that the filter can work directly on upstream sample buffers
  override public var canProcessInPlace: Bool { true }
  
  /// Initial sample rate
  private let sampleRate: Double = 44100.0
  /// Maximum number of channels to support
  private let maxNumberOfChannels: UInt32 = 8
  /// Maximum frames to render
  private let maxFramesToRender: UInt32 = 512
  /// Objective-C bridge into the C++ kernel
  private var _currentPreset: AUAudioUnitPreset? {
    didSet { os_log(.debug, log: log, "* _currentPreset name: %{public}s", _currentPreset.descriptionOrNil) }
  }
  
  private var inputBus: AUAudioUnitBus
  private var outputBus: AUAudioUnitBus
  
  private lazy var _inputBusses: AUAudioUnitBusArray = { AUAudioUnitBusArray(audioUnit: self, busType: .input,
                                                                             busses: [inputBus]) }()
  private lazy var _outputBusses: AUAudioUnitBusArray = { AUAudioUnitBusArray(audioUnit: self, busType: .output,
                                                                              busses: [outputBus]) }()
  /**
   Crete a new audio unit asynchronously.
   
   - parameter componentDescription: the component to instantiate
   - parameter options: options for instantiation
   - parameter completionHandler: closure to invoke upon creation or error
   */
  override public class func instantiate(with componentDescription: AudioComponentDescription,
                                         options: AudioComponentInstantiationOptions = [],
                                         completionHandler: @escaping (AUAudioUnit?, Error?) -> Void) {
    do {
      let auAudioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: options)
      completionHandler(auAudioUnit, nil)
    } catch {
      completionHandler(nil, error)
    }
  }
  
  /**
   Construct new instance, throwing exception if there is an error doing so.
   
   - parameter componentDescription: the component to instantiate
   - parameter options: options for instantiation
   */
  override public init(componentDescription: AudioComponentDescription,
                       options: AudioComponentInstantiationOptions = []) throws {

    // Start with the default format. Host or downstream AudioUnit can change the format of the input/output bus
    // objects later between calls to allocateRenderResources().
    guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
      os_log(.error, log: log, "failed to create AVAudioFormat format")
      throw Failure.unableToInitialize(String(describing: AVAudioFormat.self))
    }
    
    os_log(.debug, log: log, "format: %{public}s", format.description)
    inputBus = try AUAudioUnitBus(format: format)
    inputBus.maximumChannelCount = maxNumberOfChannels
    
    os_log(.debug, log: log, "creating output bus")
    outputBus = try AUAudioUnitBus(format: format)
    outputBus.maximumChannelCount = maxNumberOfChannels
    
    try super.init(componentDescription: componentDescription, options: options)
    
    os_log(.debug, log: log, "type: %{public}s, subtype: %{public}s, manufacturer: %{public}s flags: %x",
           componentDescription.componentType.stringValue,
           componentDescription.componentSubType.stringValue,
           componentDescription.componentManufacturer.stringValue,
           componentDescription.componentFlags)
    
    maximumFramesToRender = maxFramesToRender
    currentPreset = factoryPresets.first
    
    // This really should be postponed until allocateRenderResources is called. However, for some weird reason
    // internalRenderBlock is fetched before allocateRenderResources() gets called, so we need to preflight here.
    kernel.startProcessing(format, maxFramesToRender: maxFramesToRender,
                           maxDelayMilliseconds: parameters.delay.maxValue)
  }

  /**
   Take notice of input/output bus formats and prepare for rendering. If there are any errors getting things ready,
   routine should `setRenderResourcesAllocated(false)`.
   */
  override public func allocateRenderResources() throws {
    os_log(.info, log: log, "allocateRenderResources")
    os_log(.debug, log: log, "inputBus format: %{public}s", inputBus.format.description)
    os_log(.debug, log: log, "outputBus format: %{public}s", outputBus.format.description)
    os_log(.debug, log: log, "maximumFramesToRender: %d", maximumFramesToRender)
    
    if outputBus.format.channelCount != inputBus.format.channelCount {
      os_log(.error, log: log, "unequal channel count")
      setRenderResourcesAllocated(false)
      // NOTE: changing this to something else will cause `auval` to emit the following:
      //   WARNING: Can Initialize Unit to un-supported num channels:InputChan:1, OutputChan:2
      //
      throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization), userInfo: nil)
    }

    // Communicate to the kernel the new formats being used
    kernel.startProcessing(inputBus.format, maxFramesToRender: maximumFramesToRender,
                           maxDelayMilliseconds: parameters.delay.maxValue)
    
    try super.allocateRenderResources()
  }
  
  /**
   Rendering has stopped -- tear down stuff that was supporting it.
   */
  override public func deallocateRenderResources() {
    os_log(.debug, log: log, "before super.deallocateRenderResources")
    kernel.stopProcessing()
    super.deallocateRenderResources()
    os_log(.debug, log: log, "after super.deallocateRenderResources")
  }
  
  override public var internalRenderBlock: AUInternalRenderBlock {
    os_log(.info, log: log, "internalRenderBlock")
    return kernel.renderBlock();
  }
  
  override public func parametersForOverview(withCount: Int) -> [NSNumber] {
    parameters.parameters[0..<withCount].map { NSNumber(value: $0.address) }
  }
  
  override public func supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet {
    viewConfigurationManager?.supportedViewConfigurations(available) ?? IndexSet(integersIn: 0..<available.count)
  }
  
  override public func select(_ viewConfiguration: AUAudioUnitViewConfiguration) {
    viewConfigurationManager?.selectViewConfiguration(viewConfiguration)
  }
}
