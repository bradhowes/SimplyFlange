// Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Knob
import os

extension Switch: AUParameterValueProvider {
  public var value: AUValue { isOn ? 1.0 : 0.0 }
}

extension Knob: AUParameterValueProvider, RangedControl {}

/**
 Controller for the AUv3 filter view. Handles wiring up of the controls with AUParameter settings.
 */
@objc public final class FilterViewController: AUViewController {
  private let log = Logging.logger("FilterViewController")
  
  private var viewConfig: AUAudioUnitViewConfiguration!
  private var parameterObserverToken: AUParameterObserverToken?
  private var keyValueObserverToken: NSKeyValueObservation?
  
  @IBOutlet weak var controlsView: View!
  @IBOutlet weak var depthValueLabel: Label!
  @IBOutlet weak var rateValueLabel: Label!
  @IBOutlet weak var delayValueLabel: Label!
  @IBOutlet weak var feedbackValueLabel: Label!
  @IBOutlet weak var dryMixValueLabel: Label!
  @IBOutlet weak var wetMixValueLabel: Label!
  
  @IBOutlet weak var depthControl: Knob!
  @IBOutlet weak var rateControl: Knob!
  @IBOutlet weak var delayControl: Knob!
  @IBOutlet weak var feedbackControl: Knob!
  @IBOutlet weak var dryMixControl: Knob!
  @IBOutlet weak var wetMixControl: Knob!
  @IBOutlet weak var negativeFeedbackControl: Switch!
  @IBOutlet weak var odd90Control: Switch!
  
  // Alternative controls for constrained width layout
  @IBOutlet weak var altDepthControl: Knob!
  @IBOutlet weak var altDepthValueLabel: Label!
  @IBOutlet weak var altDepthTapEdit: View!
  @IBOutlet weak var altRateControl: Knob!
  @IBOutlet weak var altRateValueLabel: Label!
  @IBOutlet weak var altRateTapEdit: View!
  
#if os(iOS)
  @IBOutlet weak var depthTapEdit: UIView!
  @IBOutlet weak var rateTapEdit: UIView!
  @IBOutlet weak var delayTapEdit: UIView!
  @IBOutlet weak var feedbackTapEdit: UIView!
  @IBOutlet weak var dryMixTapEdit: UIView!
  @IBOutlet weak var wetMixTapEdit: UIView!
  
  @IBOutlet weak var editingView: View!
  @IBOutlet weak var editingLabel: Label!
  @IBOutlet weak var editingValue: UITextField!
  @IBOutlet weak var editingBackground: UIView!
#endif
  
  var controls = [FilterParameterAddress : [AUParameterControl]]()
  
  public var audioUnit: FilterAudioUnit? {
    didSet {
      performOnMain {
        if self.isViewLoaded {
          self.connectViewToAU()
        }
      }
    }
  }
  
#if os(macOS)
  
  public override init(nibName: NSNib.Name?, bundle: Bundle?) {
    super.init(nibName: nibName, bundle: Bundle(for: type(of: self)))
  }
  
#endif
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }
  
  public override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black
    if audioUnit != nil {
      connectViewToAU()
    }
    
#if os(iOS)
    
    editingBackground.layer.cornerRadius = 8.0
    
    editingView.isHidden = true
    addTapGesture(depthTapEdit)
    addTapGesture(rateTapEdit)
    addTapGesture(delayTapEdit)
    addTapGesture(feedbackTapEdit)
    addTapGesture(dryMixTapEdit)
    addTapGesture(wetMixTapEdit)
    addTapGesture(altDepthTapEdit)
    addTapGesture(altRateTapEdit)
    
#endif
    
    for control in [depthControl, altDepthControl, rateControl, altRateControl, delayControl, feedbackControl] {
      control?.trackLineWidth = 10
      control?.progressLineWidth = 8
      control?.indicatorLineWidth = 8
    }
    
    for control in [dryMixControl, wetMixControl] {
      control?.trackLineWidth = 8
      control?.progressLineWidth = 6
      control?.indicatorLineWidth = 6
    }
  }
  
  public func selectViewConfiguration(_ viewConfig: AUAudioUnitViewConfiguration) { 
    guard self.viewConfig != viewConfig else { return }
    self.viewConfig = viewConfig
  }
  
  @IBAction public func depthChanged(_ control: Knob) { controlChanged(control, address: .depth) }
  @IBAction public func rateChanged(_ control: Knob) { controlChanged(control, address: .rate) }
  @IBAction public func delayChanged(_ control: Knob) { controlChanged(control, address: .delay) }
  @IBAction public func feedbackChanged(_ control: Knob) { controlChanged(control, address: .feedback) }
  @IBAction public func dryMixChanged(_ control: Knob) { controlChanged(control, address: .dryMix) }
  @IBAction public func wetMixChanged(_ control: Knob) { controlChanged(control, address: .wetMix) }
  @IBAction public func negativeFeedbackChanged(_ control: Switch) { controlChanged(control, address: .negativeFeedback) }
  @IBAction public func odd90Changed(_ control: Switch) { controlChanged(control, address: .odd90) }

  private func controlChanged(_ control: AUParameterValueProvider, address: FilterParameterAddress) {
    audioUnit?.currentPreset = nil
    (controls[address] ?? []).forEach { $0.controlChanged(source: control) }
  }

#if os(macOS)
  override public func mouseDown(with event: NSEvent) {
    // Allow for clicks on the common NSView to end editing of values
    NSApp.keyWindow?.makeFirstResponder(nil)
  }
#endif
  
}

extension FilterViewController: AUAudioUnitFactory {
  
  /**
   Create a new FilterAudioUnit instance to run in an AVu3 container.
   
   - parameter componentDescription: descriptions of the audio environment it will run in
   - returns: new FilterAudioUnit
   */
  public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
    os_log(.info, log: log, "createAudioUnit BEGIN - %{public}s", componentDescription.description)
    audioUnit = try FilterAudioUnit(componentDescription: componentDescription, options: [.loadOutOfProcess])
    return audioUnit!
  }
}

extension FilterViewController {
  
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
    controls[.depth] = [
      FloatParameterControl(parameterObserverToken: parameterObserverToken, parameter: params[.depth],
                            formatter: params.valueFormatter(.depth), knob: depthControl,
                            label: depthValueLabel, logValues: false)
    ]
    if altDepthControl != nil {
      controls[.depth]?.append(FloatParameterControl(parameterObserverToken: parameterObserverToken,
                                                     parameter: params[.depth],
                                                     formatter: params.valueFormatter(.depth), knob: altDepthControl,
                                                     label: altDepthValueLabel, logValues: false))
    }
    
    controls[.rate] = [
      FloatParameterControl(parameterObserverToken: parameterObserverToken, parameter: params[.rate],
                            formatter: params.valueFormatter(.rate), knob: rateControl,
                            label: rateValueLabel, logValues: true)
    ]
    if altRateControl != nil {
      controls[.rate]?.append(FloatParameterControl(parameterObserverToken: parameterObserverToken,
                                                    parameter: params[.rate],
                                                    formatter: params.valueFormatter(.rate), knob: altRateControl,
                                                    label: altRateValueLabel, logValues: true))
    }
    
    controls[.delay] = [FloatParameterControl(parameterObserverToken: parameterObserverToken, parameter: params[.delay],
                                              formatter: params.valueFormatter(.delay), knob: delayControl,
                                              label: delayValueLabel, logValues: true)]
    controls[.feedback] = [FloatParameterControl(parameterObserverToken: parameterObserverToken,
                                                 parameter: params[.feedback], formatter: params.valueFormatter(.feedback),
                                                 knob: feedbackControl, label: feedbackValueLabel, logValues: false)]
    controls[.dryMix] = [FloatParameterControl(parameterObserverToken: parameterObserverToken, parameter: params[.dryMix],
                                               formatter: params.valueFormatter(.dryMix), knob: dryMixControl,
                                               label: dryMixValueLabel, logValues: false)]
    controls[.wetMix] = [FloatParameterControl(parameterObserverToken: parameterObserverToken, parameter: params[.wetMix],
                                               formatter: params.valueFormatter(.wetMix), knob: wetMixControl,
                                               label:  wetMixValueLabel, logValues: false)]
    controls[.negativeFeedback] = [BooleanParameterControl(parameterObserverToken: parameterObserverToken,
                                                           parameter: params[.negativeFeedback],
                                                           control: negativeFeedbackControl)]
    controls[.odd90] = [BooleanParameterControl(parameterObserverToken: parameterObserverToken,
                                                parameter: params[.odd90],
                                                control: odd90Control)]
  }
  
  private func updateDisplay() {
    os_log(.info, log: log, "updateDisplay")
    for address in FilterParameterAddress.allCases {
      (controls[address] ?? []).forEach { $0.parameterChanged() }
    }
  }
  
  private func performOnMain(_ operation: @escaping () -> Void) {
    (Thread.isMainThread ? operation : { DispatchQueue.main.async { operation() } })()
  }
}

#if os(iOS)

extension FilterViewController: UITextFieldDelegate {
  
  @IBAction func beginEditing(sender: UITapGestureRecognizer) {
    guard editingView.isHidden,
          let view = sender.view,
          let address = FilterParameterAddress(rawValue: UInt64(view.tag)),
          let param = controls[address]?.first?.parameter else { return }
    
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
      self.editingView.alpha = 1.0
      self.controlsView.alpha = 0.25
    } completion: { _ in
      self.editingView.alpha = 1.0
      self.controlsView.alpha = 0.25
      os_log(.info, log: self.log, "done animation")
    }
  }
  
  private func endEditing() {
    guard let address = FilterParameterAddress(rawValue: UInt64(editingView.tag)) else { fatalError() }
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
        (self.controls[address] ?? []).forEach { $0.setEditedValue(value) }
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

#endif

