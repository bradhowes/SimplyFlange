// Copyright © 2021 Brad Howes. All rights reserved.

import CoreAudioKit
import os

/**
 Controller for the AUv3 filter view.
 */
public final class FilterViewController: AUViewController {
    private let log = Logging.logger("FilterViewController")

    private var viewConfig: AUAudioUnitViewConfiguration!
    private var parameterObserverToken: AUParameterObserverToken?
    private var keyValueObserverToken: NSKeyValueObservation?

    private let logSliderMinValue: Float = 0.0
    private let logSliderMaxValue: Float = 9.0
    private lazy var logSliderMaxValuePower2Minus1 = Float(pow(2, logSliderMaxValue) - 1)

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

    var controls = [FilterParameterAddress : KnobController]()

    public var audioUnit: FilterAudioUnit? {
        didSet {
            performOnMain {
                if self.isViewLoaded {
                    self.connectViewToAU()
                }
            }
        }
    }

    #if os(iOS)
    private var bundle: Bundle { Bundle(for: FilterViewController.self) }
    private var sliderThumbImage: UIImage { UIImage(named: "SliderThumb", in: bundle, compatibleWith: nil)! }
    #endif

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
    }

    public func selectViewConfiguration(_ viewConfig: AUAudioUnitViewConfiguration) {
        guard self.viewConfig != viewConfig else { return }
        self.viewConfig = viewConfig
    }

    @IBAction func depthChanged(_: Any) { controls[.depth]?.knobChanged()}
    @IBAction func rateChanged(_: Any) { controls[.rate]?.knobChanged() }
    @IBAction func delayChanged(_: Any) { controls[.delay]?.knobChanged() }
    @IBAction func feedbackChanged(_: Any) { controls[.feedback]?.knobChanged() }
    @IBAction func dryMixChanged(_: Any) { controls[.dryMix]?.knobChanged() }
    @IBAction func wetMixChanged(_: Any) { controls[.wetMix]?.knobChanged() }
}

extension FilterViewController: AUAudioUnitFactory {

    /**
     Create a new FilterAudioUnit instance to run in an AVu3 container.

     - parameter componentDescription: descriptions of the audio environment it will run in
     - returns: new FilterAudioUnit
     */
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        os_log(.info, log: log, "creating new audio unit")
        componentDescription.log(log, type: .debug)
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
        controls[.depth] = KnobController(parameterObserverToken: parameterObserverToken,
                                          parameter: params[.depth],
                                          formatter: params.valueFormatter(.depth),
                                          knob: depthControl,
                                          label: depthValueLabel,
                                          logValues: false)

        controls[.rate] = KnobController(parameterObserverToken: parameterObserverToken,
                                         parameter: params[.rate],
                                         formatter: params.valueFormatter(.rate),
                                         knob: rateControl,
                                         label: rateValueLabel,
                                         logValues: true)
        controls[.delay] = KnobController(parameterObserverToken: parameterObserverToken,
                                          parameter: params[.delay],
                                          formatter: params.valueFormatter(.delay),
                                          knob: delayControl,
                                          label: delayValueLabel,
                                          logValues: true)
        controls[.feedback] = KnobController(parameterObserverToken: parameterObserverToken,
                                             parameter: params[.feedback],
                                             formatter: params.valueFormatter(.feedback),
                                             knob: feedbackControl,
                                             label: feedbackValueLabel,
                                             logValues: false)
        controls[.dryMix] = KnobController(parameterObserverToken: parameterObserverToken,
                                           parameter: params[.dryMix],
                                           formatter: params.valueFormatter(.dryMix),
                                           knob: dryMixControl,
                                           label: dryMixValueLabel,
                                           logValues: false)
        controls[.wetMix] = KnobController(parameterObserverToken: parameterObserverToken,
                                           parameter: params[.wetMix],
                                           formatter: params.valueFormatter(.wetMix),
                                           knob: wetMixControl,
                                           label:  wetMixValueLabel,
                                           logValues: false)
    }

    private func updateDisplay() {
        os_log(.info, log: log, "updateDisplay")
        for address in FilterParameterAddress.allCases {
            controls[address]?.parameterChanged()
        }
    }

    private func performOnMain(_ operation: @escaping () -> Void) {
        (Thread.isMainThread ? operation : { DispatchQueue.main.async { operation() } })()
    }
}
