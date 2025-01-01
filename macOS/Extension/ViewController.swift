// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Kernel
import KernelBridge
import Knob_macOS
import ParameterAddress
import Parameters
import os.log

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log: OSLog = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private var viewConfig: AUAudioUnitViewConfiguration!
  private var versionTagValue: String = ""

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

  @IBOutlet private weak var versionTag: NSTextField!

  private lazy var controls: [ParameterAddress: (Knob, FocusAwareTextField)] = [
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

  private var editors = [AUParameterEditor]()
  private var editorMap = [ParameterAddress : AUParameterEditor]()

  public var audioUnit: FilterAudioUnit? {
    didSet {
      DispatchQueue.main.async {
        if self.isViewLoaded {
          self.createEditors()
        }
      }
    }
  }
}

public extension ViewController {

  override func viewDidLoad() {
    os_log(.info, log: log, "viewDidLoad BEGIN")
    super.viewDidLoad()
    view.backgroundColor = .black

    if audioUnit != nil {
      createEditors()
    }
    os_log(.info, log: log, "viewDidLoad END")
  }

  override func viewDidAppear() {
    versionTag.text = versionTagValue
  }

  override func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)
  }
}

// MARK: - AudioUnitViewConfigurationManager

extension ViewController: AudioUnitViewConfigurationManager {}

// MARK: - AUAudioUnitFactory

extension ViewController: AUAudioUnitFactory {

  nonisolated public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    try DispatchQueue.main.sync {
      let bundle = InternalConstants.bundle
      let parameters = Parameters()
      let kernel = KernelBridge(bundle.auBaseName, maxDelayMilliseconds: parameters[.delay].maxValue)
      let audioUnit = try FilterAudioUnitFactory.create(componentDescription: componentDescription,
                                                        parameters: parameters, kernel: kernel,
                                                        viewConfigurationManager: self)
      self.audioUnit = audioUnit
      self.versionTagValue = bundle.versionTag

      return audioUnit
    }
  }
}

// MARK: - Private

extension ViewController: AUParameterEditorDelegate {
  public func parameterEditorEditingDone(changed: Bool) {
    if changed {
      audioUnit?.clearCurrentPresetIfFactoryPreset()
    }
  }
}

private extension ViewController {

  func createEditors() {
    os_log(.info, log: log, "createEditors BEGIN")

    guard let audioUnit,
          let parameterTree = audioUnit.parameterTree
    else {
      return
    }

    let knobColor = NSColor.knobProgress

    for (parameterAddress, (knob, label)) in controls {
      knob.progressColor = knobColor
      knob.indicatorColor = knobColor

      knob.target = self
      knob.action = #selector(handleKnobValueChanged(_:))

      let editor = FloatParameterEditor(parameter: parameterTree[parameterAddress],
                                        formatting: parameterTree[parameterAddress],
                                        rangedControl: knob, label: label)
      editor.delegate = self
      editors.append(editor)
      editorMap[parameterAddress] = editor
    }

    for (parameterAddress, control) in switches {
      control.setTint(knobColor)
      let editor = BooleanParameterEditor(parameter: parameterTree[parameterAddress], booleanControl: control)
      control.target = self
      control.action = #selector(handleSwitchValueChanged(_:))
      editors.append(editor)
      editorMap[parameterAddress] = editor
    }

    os_log(.info, log: log, "createEditors END")
  }

  @IBAction func handleKnobValueChanged(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  @IBAction func handleSwitchValueChanged(_ control: Switch) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  func handleControlChanged(_ control: AUParameterValueProvider, address: ParameterAddress) {
    guard let audioUnit,
          let parameterTree = audioUnit.parameterTree
    else {
      return
    }

    os_log(.debug, log: log, "controlChanged BEGIN - %d %f %f", address.rawValue, control.value,
           parameterTree[address].value)

    guard let editor = editorMap[address] else {
      os_log(.debug, log: log, "controlChanged END - nil editor")
      return
    }

    if editor.differs {
      audioUnit.clearCurrentPresetIfFactoryPreset()
    }

    editor.controlChanged(source: control)
  }
}

private enum InternalConstants {
  private class EmptyClass {}
  static let bundle = Bundle(for: InternalConstants.EmptyClass.self)
}

extension Knob: @retroactive AUParameterValueProvider, @retroactive RangedControl {}

extension AUParameterTree {
  fileprivate subscript (_ parameter: ParameterAddress) -> AUParameter {
    guard let parameter = self.parameter(source: parameter) else {
      fatalError("Unexpected parameter address \(parameter)")
    }
    return parameter
  }
}
