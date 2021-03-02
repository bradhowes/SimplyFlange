// Copyright © 2021 Brad Howes. All rights reserved.

import CoreAudioKit
import os

/**
 Controller for a knob and text view / label
 */
final class KnobController: NSObject {
    private let log = Logging.logger("KnobController")

    private let logSliderMinValue: Float = 0.0
    private let logSliderMaxValue: Float = 9.0
    private lazy var logSliderMaxValuePower2Minus1 = Float(pow(2, logSliderMaxValue) - 1)

    private let parameterObserverToken: AUParameterObserverToken
    private let parameter: AUParameter
    private let formatter: (AUValue) -> String
    private let knob: Knob
    private let label: Label
    private let useLogValues: Bool
    private var restoreNameTimer: Timer?

    init(parameterObserverToken: AUParameterObserverToken, parameter: AUParameter,
         formatter: @escaping (AUValue) -> String, knob: Knob, label: Label,
         logValues: Bool) {
        self.parameterObserverToken = parameterObserverToken
        self.parameter = parameter
        self.formatter = formatter
        self.knob = knob
        self.label = label
        self.useLogValues = logValues
        super.init()

        self.label.text = parameter.displayName

        if useLogValues {
            knob.minimumValue = logSliderMinValue
            knob.maximumValue = logSliderMaxValue
            knob.value = logKnobLocationForParameterValue()
        }
        else {
            knob.minimumValue = parameter.minValue
            knob.maximumValue = parameter.maxValue
            knob.value = parameter.value
        }
    }
}

extension KnobController {

    func knobChanged() {
        let value = useLogValues ? parameterValueForLogSliderLocation() : knob.value
        setValue(formatter(value))
        parameter.setValue(value, originator: parameterObserverToken)
    }

    func parameterChanged() {
        setValue(formatter(parameter.value))
        knob.value = useLogValues ? logKnobLocationForParameterValue() : parameter.value
    }
}

extension KnobController {

    private func logKnobLocationForParameterValue() -> Float {
        log2(((parameter.value - parameter.minValue) / (parameter.maxValue - parameter.minValue)) *
                logSliderMaxValuePower2Minus1 + 1.0)
    }

    private func parameterValueForLogSliderLocation() -> AUValue {
        ((pow(2, knob.value) - 1) / logSliderMaxValuePower2Minus1) * (parameter.maxValue - parameter.minValue) +
            parameter.minValue
    }

    private func setValue(_ value: String) {
        label.text = value
        restoreName()
    }

    private func restoreName() {
        restoreNameTimer?.invalidate()
        restoreNameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            UIView.transition(with: self.label, duration: 0.5, options: [.curveLinear, .transitionCrossDissolve]) {
                self.label.text = self.parameter.displayName
            } completion: { _ in
                self.label.text = self.parameter.displayName
            }
        }
    }
}
