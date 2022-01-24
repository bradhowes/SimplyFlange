// Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import os

/**
 Controller for a knob and text view / label.
 */
final class SwitchController: AUParameterControl {
  private let log = Logging.logger("SwitchController")
  
  private let parameterObserverToken: AUParameterObserverToken
  let parameter: AUParameter
  let _control: Switch
  
  var control: NSObject { _control }
  
  init(parameterObserverToken: AUParameterObserverToken, parameter: AUParameter, control: Switch) {
    self.parameterObserverToken = parameterObserverToken
    self.parameter = parameter
    self._control = control
    control.isOn = parameter.value > 0.0 ? true : false
  }
}

extension SwitchController {
  
  func controlChanged() {
    os_log(.info, log: log, "controlChanged - %d", _control.isOn)
    parameter.setValue(_control.isOn ? 1.0 : 0.0, originator: parameterObserverToken)
  }
  
  func parameterChanged() {
    os_log(.info, log: log, "parameterChanged - %f", parameter.value)
    _control.isOn = parameter.value > 0.0 ? true : false
  }
  
  func setEditedValue(_ value: AUValue) {
    parameter.setValue(_control.isOn ? 1.0 : 0.0, originator: parameterObserverToken)
  }
}
