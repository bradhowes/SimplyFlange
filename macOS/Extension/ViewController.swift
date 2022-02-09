// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Kernel
import KernelBridge
import Knob_macOS
import ParameterAddress
import Parameters
import os.log

extension NSSwitch: AUParameterValueProvider, BooleanControl, TagHolder {
  public var value: AUValue { isOn ? 1.0 : 0.0 }
}

extension Knob: AUParameterValueProvider, RangedControl {}

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log: OSLog = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private var viewConfig: AUAudioUnitViewConfiguration!
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

  @IBOutlet private weak var odd90Control: NSSwitch!
  @IBOutlet private weak var negativeFeedbackControl: NSSwitch!

  private lazy var pairs: [ParameterAddress: (Knob, FocusAwareTextField)] = [
    .depth: (depthControl, depthValueLabel),
    .rate: (rateControl, rateValueLabel),
    .delay: (delayControl, delayValueLabel),
    .feedback: (feedbackControl, feedbackValueLabel),
    .wet: (wetMixControl, wetMixValueLabel),
    .dry: (dryMixControl, dryMixValueLabel)
  ]

  private lazy var switches: [ParameterAddress: NSSwitch] = [
    .odd90: odd90Control,
    .negativeFeedback: negativeFeedbackControl
  ]

  private var editors = [ParameterAddress : AUParameterEditor]()
  
  public var audioUnit: FilterAudioUnit? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.connectViewToAU()
        }
      }
    }
  }

  public override func viewDidLoad() {
    os_log(.info, log: log, "viewDidLoad BEGIN")

    super.viewDidLoad()

    view.backgroundColor = .black
    if audioUnit != nil {
      connectViewToAU()
    }

    os_log(.info, log: log, "viewDidLoad END")
  }

  private func createEditors() {
    os_log(.info, log: log, "createEditors BEGIN")

    let knobColor = NSColor(named: "knob")!

    os_log(.info, log: log, "createEditors - creating float parameter editors")
    for (parameterAddress, (knob, label)) in pairs {
      os_log(.info, log: log, "createEditors - [%d] %{public}s %{public}s", parameterAddress.rawValue,
             knob.pointer, label.pointer)

      os_log(.info, log: log, "createEditors - creating float parameter editor: %{public}s",
             parameterAddress.description)

      knob.progressColor = knobColor
      knob.indicatorColor = knobColor

      if parameterAddress == .wet || parameterAddress == .dry {
        knob.trackLineWidth = 8
        knob.progressLineWidth = 6
        knob.indicatorLineWidth = 6
      } else {
        knob.trackLineWidth = 10
        knob.progressLineWidth = 8
        knob.indicatorLineWidth = 8
      }

      knob.target = self
      knob.action = #selector(handleKnobValueChanged(_:))

      os_log(.info, log: log, "createEditors - before FloatParameterEditor")
      editors[parameterAddress] = FloatParameterEditor(parameter: parameters[parameterAddress],
                                                       formatter: parameters.valueFormatter(parameterAddress),
                                                       rangedControl: knob, label: label)
    }

    os_log(.info, log: log, "createEditors - creating bool parameter editors")
    for (parameterAddress, control) in switches {
      control.wantsLayer = true
      control.layer?.backgroundColor = knobColor.cgColor
      control.layer?.masksToBounds = true
      control.layer?.cornerRadius = 10

      os_log(.info, log: log, "createEditors - before BooleanParameterEditor")
      editors[parameterAddress] = BooleanParameterEditor(parameter: parameters[parameterAddress],
                                                         booleanControl: control)
    }

    os_log(.info, log: log, "createEditors END")
  }

  @IBAction private func handleKnobValueChanged(_ control: Knob) {
     guard let address = control.parameterAddress else { fatalError() }
     handleControlChanged(control, address: address)
  }

  @IBAction private func handleOdd90Changed(_ control: NSSwitch) {
    handleControlChanged(control, address: .odd90)
  }

  @IBAction private func handleNegativeFeedbackChanged(_ control: NSSwitch) {
    handleControlChanged(control, address: .negativeFeedback)
  }

  private func handleControlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    os_log(.debug, log: log, "controlChanged BEGIN - %d %f", address.rawValue, control.value)

    guard let audioUnit = audioUnit else {
      os_log(.debug, log: log, "controlChanged END - nil audioUnit")
      return
    }

    // When user changes something and a factory preset was active, clear it.
    if let preset = audioUnit.currentPreset, preset.number >= 0 {
      os_log(.debug, log: log, "controlChanged - clearing currentPreset")
      audioUnit.currentPreset = nil
    }

    editors[address]?.controlChanged(source: control)
  }

  override public func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)
  }
}

extension ViewController: AUAudioUnitFactory {
  
  /**
   Create a new FilterAudioUnit instance to run in an AVu3 container.
   
   - parameter componentDescription: descriptions of the audio environment it will run in
   - returns: new FilterAudioUnit
   */
  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    os_log(.info, log: log, "createAudioUnit BEGIN - %{public}s", componentDescription.description)

    let kernel = KernelBridge(Bundle.main.auBaseName, maxDelayMilliseconds: parameters[.delay].maxValue)
    parameters.setParameterHandler(kernel)

    let audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
    self.audioUnit = audioUnit

    audioUnit.setParameters(parameters)
    audioUnit.setKernel(kernel)
    
    os_log(.info, log: log, "createAudioUnit END")
    return audioUnit
  }
}

extension ViewController {

  override public func viewWillTransition(to newSize: NSSize) {
    os_log(.debug, log: log, "viewWillTransition: %f x %f", newSize.width, newSize.height)
  }

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU BEGIN")
    
    guard let audioUnit = audioUnit else { fatalError("unexpected nil audioUnit") }

    createEditors()

    keyValueObserverToken = audioUnit.observe(\.allParameterValues) { _, _ in
      DispatchQueue.main.async {
        if audioUnit.currentPreset != nil {
          self.updateDisplay()
        }
      }
    }

    // Let us manage view configuration changes
    audioUnit.viewConfigurationManager = self

    os_log(.info, log: log, "connectViewToAU END")
  }
  
  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in ParameterAddress.allCases {
      editors[address]?.parameterChanged()
    }
  }
}

extension ViewController: AudioUnitViewConfigurationManager {

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
