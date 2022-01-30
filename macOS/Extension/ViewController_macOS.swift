// Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import FilterAudioUnit
import Kernel
import Knob_macOS
import Logging
import Parameters
import os.log

extension Switch: AUParameterValueProvider {
  public var value: AUValue { isOn ? 1.0 : 0.0 }
}

extension Knob: AUParameterValueProvider, RangedControl {

  func setParameterAddress(_ address: ParameterAddress) { tag = Int(address.rawValue) }

  var parameterAddress: ParameterAddress? { ParameterAddress(rawValue: UInt64(tag) ) }
}

extension FocusAwareTextField {

  func setParameterAddress(_ address: ParameterAddress) { tag = Int(address.rawValue) }

  var parameterAddress: ParameterAddress? { ParameterAddress(rawValue: UInt64(tag) ) }
}


/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController_macOS: AUViewController {
  private let log = Logging.logger("ViewController_macOS")
  
  private var viewConfig: AUAudioUnitViewConfiguration!
  private var parameterObserverToken: AUParameterObserverToken?
  private var keyValueObserverToken: NSKeyValueObservation?
  private var hasActiveLabel = false

  @IBOutlet private weak var controlsView: NSView!

  @IBOutlet private weak var depthControl: Knob!
  @IBOutlet private weak var depthValueLabel: FocusAwareTextField!

  @IBOutlet private weak var rateControl: Knob!
  @IBOutlet private weak var rateValueLabel: FocusAwareTextField!

  @IBOutlet private weak var delayControl: Knob!
  @IBOutlet private weak var delayValueLabel: FocusAwareTextField!

  @IBOutlet private weak var feedbackControl: Knob!
  @IBOutlet private weak var feedbackValueLabel: FocusAwareTextField!

  @IBOutlet private weak var wetMixControl: Knob!
  @IBOutlet private weak var wetMixValueLabel: FocusAwareTextField!
  
  @IBOutlet private weak var dryMixControl: Knob!
  @IBOutlet private weak var dryMixValueLabel: FocusAwareTextField!

  @IBOutlet private weak var odd90Control: Switch!
  @IBOutlet private weak var negativeFeedbackControl: Switch!

  var controls = [ParameterAddress : [AUParameterControl]]()
  
  public var audioUnit: FilterAudioUnit? {
    didSet {
      performOnMain {
        if self.isViewLoaded {
          self.connectViewToAU()
        }
      }
    }
  }

  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    if audioUnit != nil {
      connectViewToAU()
    }

    // Set tag values to AUParameter address values for use in editing tasks
    //
    depthControl.setParameterAddress(.depth)
    depthValueLabel.setParameterAddress(.depth)

    rateControl.setParameterAddress(.rate)
    rateValueLabel.setParameterAddress(.rate)

    delayControl.setParameterAddress(.delay)
    delayValueLabel.setParameterAddress(.delay)

    feedbackControl.setParameterAddress(.feedback)
    feedbackValueLabel.setParameterAddress(.feedback)

    wetMixControl.setParameterAddress(.wetMix)
    wetMixValueLabel.setParameterAddress(.wetMix)

    dryMixControl.setParameterAddress(.dryMix)
    dryMixValueLabel.setParameterAddress(.dryMix)

    for control in [depthControl, rateControl, delayControl, feedbackControl] {
      if let control = control {
        control.trackLineWidth = 10
        control.progressLineWidth = 8
        control.indicatorLineWidth = 8
        control.target = self
        control.action = #selector(valueChanged(_:))
      }
    }
    
    for control in [dryMixControl, wetMixControl] {
      if let control = control {
        control.trackLineWidth = 8
        control.progressLineWidth = 6
        control.indicatorLineWidth = 6
        control.target = self
        control.action = #selector(valueChanged(_:))
      }
    }
  }

  @IBAction public func valueChanged(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    controlChanged(control, address: address)
  }

  @IBAction public func odd90Changed(_ control: Switch) { controlChanged(control, address: .odd90) }
  @IBAction public func negativeFeedbackChanged(_ control: Switch) { controlChanged(control, address: .negativeFeedback) }

  private func controlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    os_log(.debug, log: log, "controlChanged BEGIN - %d %f", address.rawValue, control.value)

    // If current preset is a factory preset, then clear it.
    if (audioUnit?.currentPreset?.number ?? -1) > 0 {
      audioUnit?.currentPreset = nil
    }

    (controls[address] ?? []).forEach { $0.controlChanged(source: control) }
  }

  override public func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)
  }
}

extension ViewController_macOS: AUAudioUnitFactory {
  
  /**
   Create a new FilterAudioUnit instance to run in an AVu3 container.
   
   - parameter componentDescription: descriptions of the audio environment it will run in
   - returns: new FilterAudioUnit
   */
  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    os_log(.info, log: log, "createAudioUnit BEGIN - %{public}s", componentDescription.description)
    audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
    os_log(.info, log: log, "createAudioUnit END")
    return audioUnit!
  }
}

extension ViewController_macOS {

  override public func viewWillTransition(to newSize: NSSize) {
    os_log(.debug, log: log, "viewWillTransition: %f x %f", newSize.width, newSize.height)
  }

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")
    
    guard parameterObserverToken == nil else { return }
    guard let audioUnit = audioUnit else { fatalError("logic error -- nil audioUnit value") }
    guard let paramTree = audioUnit.parameterTree else { fatalError("logic error -- nil parameterTree") }
    
    keyValueObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      self.performOnMain { self.updateDisplay() }
    }
    
    let parameterObserverToken = paramTree.token(byAddingParameterObserver: { [weak self] _, _ in
      guard let self = self else { return }
      self.performOnMain { self.updateDisplay() }
    })
    
    self.parameterObserverToken = parameterObserverToken
    
    let params = audioUnit.parameterDefinitions
    controls[.depth] = [FloatParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.depth],
      formatter: params.valueFormatter(.depth), rangedControl: depthControl, label: depthValueLabel, logValues: false
    )]
    controls[.rate] = [FloatParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.rate], formatter: params.valueFormatter(.rate),
      rangedControl: rateControl, label: rateValueLabel, logValues: true
    )]
    controls[.delay] = [FloatParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.delay],
      formatter: params.valueFormatter(.delay), rangedControl: delayControl, label: delayValueLabel, logValues: true
    )]
    controls[.feedback] = [FloatParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.feedback],
      formatter: params.valueFormatter(.feedback), rangedControl: feedbackControl, label: feedbackValueLabel,
      logValues: false
    )]
    controls[.dryMix] = [FloatParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.dryMix],
      formatter: params.valueFormatter(.dryMix), rangedControl: dryMixControl, label: dryMixValueLabel,
      logValues: false
    )]
    controls[.wetMix] = [FloatParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.wetMix],
      formatter: params.valueFormatter(.wetMix), rangedControl: wetMixControl, label:  wetMixValueLabel,
      logValues: false
    )]
    controls[.negativeFeedback] = [BooleanParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.negativeFeedback],
      booleanControl: negativeFeedbackControl
    )]
    controls[.odd90] = [BooleanParameterControl(
      parameterObserverToken: parameterObserverToken, parameter: params[.odd90], booleanControl: odd90Control
    )]

    // Let us manage view configuration changes
    audioUnit.viewConfigurationManager = self
  }
  
  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in ParameterAddress.allCases {
      (controls[address] ?? []).forEach { $0.parameterChanged() }
    }
  }
  
  private func performOnMain(_ operation: @escaping () -> Void) {
    (Thread.isMainThread ? operation : { DispatchQueue.main.async { operation() } })()
  }
}

extension ViewController_macOS: AudioUnitViewConfigurationManager {

  public func supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet {
    var indexSet = IndexSet()
    for (index, viewConfiguration) in available.enumerated() {
      if viewConfiguration.width > 0 && viewConfiguration.height > 0 {
        indexSet.insert(index)
      }
    }
    return indexSet
  }

  public func selectViewConfiguration(_ viewConfiguration: AUAudioUnitViewConfiguration) {

  }
}
