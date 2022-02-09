// Copyright © 2022 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import KernelBridge
import Kernel
import Knob_iOS
import ParameterAddress
import Parameters
import os.log

extension UISwitch: AUParameterValueProvider, TagHolder, BooleanControl {
  public var value: AUValue { isOn ? 1.0 : 0.0 }
}

extension Knob: AUParameterValueProvider, RangedControl, TagHolder {}

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc open class ViewController: AUViewController {

  // NOTE: this special form sets the subsystem name and must run before any other logger calls.
  private let log = Shared.logger(Bundle.main.auBaseName + "AU", "ViewController")

  private let parameters = AudioUnitParameters()
  private var viewConfig: AUAudioUnitViewConfiguration!
  private var keyValueObserverToken: NSKeyValueObservation?

  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var controlsView: View!

  @IBOutlet weak var depthControl: Knob!
  @IBOutlet weak var depthValueLabel: Label!
  @IBOutlet weak var depthTapEdit: UIView!

  @IBOutlet weak var delayControl: Knob!
  @IBOutlet weak var delayValueLabel: Label!
  @IBOutlet weak var delayTapEdit: UIView!

  @IBOutlet weak var rateControl: Knob!
  @IBOutlet weak var rateValueLabel: Label!
  @IBOutlet weak var rateTapEdit: UIView!

  @IBOutlet weak var feedbackControl: Knob!
  @IBOutlet weak var feedbackValueLabel: Label!
  @IBOutlet weak var feedbackTapEdit: UIView!

  @IBOutlet weak var altDepthControl: Knob!
  @IBOutlet weak var altDepthValueLabel: Label!
  @IBOutlet weak var altDepthTapEdit: View!

  @IBOutlet weak var altDelayControl: Knob!
  @IBOutlet weak var altDelayValueLabel: Label!
  @IBOutlet weak var altDelayTapEdit: View!

  @IBOutlet weak var dryMixControl: Knob!
  @IBOutlet weak var dryMixValueLabel: Label!
  @IBOutlet weak var dryMixTapEdit: UIView!

  @IBOutlet weak var wetMixControl: Knob!
  @IBOutlet weak var wetMixValueLabel: Label!
  @IBOutlet weak var wetMixTapEdit: UIView!

  @IBOutlet weak var odd90Control: Switch!
  @IBOutlet weak var negativeFeedbackControl: Switch!

  // Holds all of the other editing views and is used to end editing when tapped.
  @IBOutlet weak var editingView: View!
  // Background that contains the label and value editor field. Always appears just above the keyboard view.
  @IBOutlet weak var editingBackground: UIView!
  // Shows the name of the value being edited
  @IBOutlet weak var editingLabel: Label!
  // Shows the name of the value being edited
  @IBOutlet weak var editingValue: UITextField!

  // The top constraint of the editingView. Set to 0 when loaded, but otherwise not used.
  @IBOutlet weak var editingViewTopConstraint: NSLayoutConstraint!
  // The bottom constraint of the editingBackground that controls the vertical position of the editor
  @IBOutlet weak var editingBackgroundBottomConstraint: NSLayoutConstraint!

  // Mapping of parameter address value to array of controls. Use array since two controls exist in pairs to handle
  // constrained width layouts.
  private var editors = [ParameterAddress : [AUParameterEditor]]()

  private lazy var pairs: [ParameterAddress: [(Knob, Label)]] = [
    .depth: [(depthControl, depthValueLabel),
             (altDepthControl, altDelayValueLabel)],
    .delay: [(delayControl, delayValueLabel),
             (altDelayControl, altDelayValueLabel)],
    .rate: [(rateControl, rateValueLabel)],
    .feedback: [(feedbackControl, feedbackValueLabel)],
    .wet: [(wetMixControl, wetMixValueLabel)],
    .dry: [(dryMixControl, dryMixValueLabel)]
  ]

  private lazy var switches: [ParameterAddress: Switch] = [
    .odd90: odd90Control,
    .negativeFeedback: negativeFeedbackControl
  ]

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

    editingViewTopConstraint.constant = 0
    editingBackgroundBottomConstraint.constant = view.frame.midY

    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardAppearing(_:)),
                                           name: UIApplication.keyboardWillShowNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDisappearing(_:)),
                                           name: UIApplication.keyboardWillHideNotification, object: nil)

    editingBackground.layer.cornerRadius = 8.0
    editingView.isHidden = true

    addTapGesture(depthTapEdit)
    addTapGesture(delayTapEdit)
    addTapGesture(rateTapEdit)
    addTapGesture(feedbackTapEdit)
    addTapGesture(dryMixTapEdit)
    addTapGesture(wetMixTapEdit)
    addTapGesture(altDepthTapEdit)
    addTapGesture(altDelayTapEdit)

    os_log(.info, log: log, "viewDidLoad BEGIN")
  }

  private func createEditors() {
    os_log(.info, log: log, "createEditors BEGIN")

    let knobColor = UIColor(named: "knob")!

    for (parameterAddress, pairs) in pairs {
      var editors = [AUParameterEditor]()
      for (knob, label) in pairs {

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

        editors.append(FloatParameterEditor(parameter: parameters[parameterAddress],
                                            formatter: parameters.valueFormatter(parameterAddress),
                                            rangedControl: knob, label: label))
      }
      self.editors[parameterAddress] = editors
    }

    os_log(.info, log: log, "createEditors - creating bool parameter editors")
    for (parameterAddress, control) in switches {
      os_log(.info, log: log, "createEditors - before BooleanParameterEditor")
      editors[parameterAddress] = [BooleanParameterEditor(parameter: parameters[parameterAddress],
                                                         booleanControl: control)]
    }

    os_log(.info, log: log, "createEditors END")
  }

  @IBAction func handleKeyboardAppearing(_ notification: NSNotification) {
    os_log(.info, log: log, "handleKeyboardAppearing BEGIN")

    guard let info = notification.userInfo else {
      os_log(.error, log: log, "handleKeyboardAppearing END - no userInfo dict")
      return
    }

    guard let keyboardFrameEnd = info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
      os_log(.error, log: log, "handleKeyboardAppearing END - no userInfo entry for %{public}s",
             UIResponder.keyboardFrameEndUserInfoKey)
      return
    }

    let keyboardFrame = keyboardFrameEnd.cgRectValue
    let localKeyboardFrame = view.convert(keyboardFrame, from: view.window)
    os_log(.info, log: log, "handleKeyboardAppearing - height: %f", localKeyboardFrame.height)

    view.layoutIfNeeded()
    UIView.animate(withDuration: 0.4, delay: 0.0) {
      if localKeyboardFrame.height < 100 {
        self.editingBackgroundBottomConstraint.constant = self.view.frame.midY
      } else {
        self.editingBackgroundBottomConstraint.constant = localKeyboardFrame.height + 20
      }
      self.view.layoutIfNeeded()
    }
  }

  @IBAction func handleKeyboardDisappearing(_ notification: NSNotification) {
    view.layoutIfNeeded()
    UIView.animate(withDuration: 0.4, delay: 0.0) {
      self.editingBackgroundBottomConstraint.constant = self.view.frame.midY
      self.view.layoutIfNeeded()
    }
  }

  @IBAction public func handleKnobValueChange(_ control: Knob) {
    guard let address = control.parameterAddress else { fatalError() }
    handleControlChanged(control, address: address)
  }

  @IBAction public func handleOdd90Change(_ control: Switch) {
    handleControlChanged(control, address: .odd90)
  }

  @IBAction public func handleNegativeFeedbackChange(_ control: Switch) {
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

    (editors[address] ?? []).forEach { $0.controlChanged(source: control) }

    os_log(.debug, log: log, "controlChanged END")
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

  private func connectViewToAU() {
    os_log(.info, log: log, "connectViewToAU")
    guard let audioUnit = audioUnit else { fatalError("logic error -- nil audioUnit value") }

    createEditors()

    keyValueObserverToken = audioUnit.observe(\.allParameterValues) { [weak self] _, _ in
      guard let self = self else { return }
      DispatchQueue.main.async {
        if audioUnit.currentPreset != nil {
          self.updateDisplay()
        }
      }
    }

    // Let us manage view configuration changes
    audioUnit.viewConfigurationManager = self
  }

  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in ParameterAddress.allCases {
      (editors[address] ?? []).forEach { $0.parameterChanged() }
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

extension ViewController: UITextFieldDelegate {

  @IBAction func beginEditing(sender: UITapGestureRecognizer) {
    guard editingView.isHidden,
          let view = sender.view,
          let address = ParameterAddress(rawValue: UInt64(view.tag)),
          let param = editors[address]?.first?.parameter
    else {
      return
    }

#if targetEnvironment(macCatalyst)
    editingBackgroundBottomConstraint = view.frame.midY
#endif

    os_log(.info, log: log, "beginEditing - %d", view.tag)
    editingView.tag = view.tag
    editingLabel.text = param.displayName
    editingValue.text = "\(param.value)"
    editingValue.becomeFirstResponder()
    editingValue.delegate = self

    editingView.alpha = 0.0
    editingView.isHidden = false

    os_log(.info, log: log, "starting animation")
    UIView.animate(withDuration: 0.4, delay: 0.0, options: [.curveEaseIn]) {
      self.controlsView.alpha = 0.40
      self.editingView.alpha = 1.0
    } completion: { _ in
      self.controlsView.alpha = 0.40
      os_log(.info, log: self.log, "done animation")
    }
  }

  private func endEditing() {
    guard let address = ParameterAddress(rawValue: UInt64(editingView.tag)) else { fatalError() }
    os_log(.info, log: log, "endEditing - %d", editingView.tag)

    editingValue.resignFirstResponder()

    os_log(.info, log: log, "starting animation")
    UIView.animate(withDuration: 0.4, delay: 0.0, options: [.curveEaseIn]) {
      self.editingView.alpha = 0.0
      self.controlsView.alpha = 1.0
    } completion: { _ in
      self.editingView.alpha = 0.0
      self.controlsView.alpha = 1.0
      self.editingView.isHidden = true
      if let stringValue = self.editingValue.text,
         let value = Float(stringValue) {
        (self.editors[address] ?? []).forEach { $0.setEditedValue(value) }
      }
      os_log(.info, log: self.log, "done animation")
    }
  }

  override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if !editingView.isHidden {
      endEditing()
    }
    super.touchesBegan(touches, with: event)
  }

  private func addTapGesture(_ view: UIView) {
    let gesture = UITapGestureRecognizer(target: self, action: #selector(beginEditing))
    gesture.numberOfTouchesRequired = 1
    gesture.numberOfTapsRequired = 1
    view.addGestureRecognizer(gesture)
    view.isUserInteractionEnabled = true
  }

  public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    os_log(.info, log: log, "textFieldShouldReturn")
    endEditing()
    return false
  }

  public func textFieldDidEndEditing(_ textField: UITextField) {
    os_log(.info, log: log, "textFieldDidEndEditing")
    if textField.isFirstResponder {
      endEditing()
    }
  }
}
