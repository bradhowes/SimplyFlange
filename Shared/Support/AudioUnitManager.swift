// Copyright © 2021 Brad Howes. All rights reserved.

import AVFoundation
import os

/**
 Delegation protocol for AudioUnitManager class.
 */
public protocol AudioUnitManagerDelegate: class {

    /**
     Notification that the FilterViewController in the AudioUnitManager has a FilterAudioUnit
     */
    func connected()
}

/**
 Simple hosting container for the FilterAudioUnit when used in an application. Loads the view controller for the
 AudioUnit and then instantiates the audio unit itself. Finally, it wires the AudioUnit with SimplePlayEngine to
 send audio samples to the AudioUnit.
 */
public final class AudioUnitManager {
    private static let log = Logging.logger("AudioUnitManager")
    private var log: OSLog { Self.log }

    private let playEngine = SimplePlayEngine()

    private var _viewController: FilterViewController?

    /// View controller for the AudioUnit interface. NOTE: this is only valid after the delegate `connected` function
    /// is called -- invoked before and it will raise an fatal error.
    public var viewController: FilterViewController { _viewController! }

    /// True if the audio engine is currently playing
    public var isPlaying: Bool { playEngine.isPlaying }

    /// The AudioUnit being managed.
    public var audioUnit: FilterAudioUnit? { _viewController?.audioUnit }

    /// Delegate to signal when everything is wired up.
    public weak var delegate: AudioUnitManagerDelegate? { didSet { signalConnected() } }

    /**
     Create a new instance. Instantiates new FilterAudioUnit and its view controller.
     */
    public init(componentDescription: AudioComponentDescription, appExtension: String) {
        let viewController = Self.loadViewController(appExtension: appExtension)
        createAudioUnit2(componentDescription: componentDescription, viewController: viewController)
    }
}

extension AudioUnitManager {

    private func createAudioUnit(componentDescription: AudioComponentDescription) {
        os_log(.info, log: log, "createAudioUnit")
        componentDescription.log(log, type: .info)

        // Uff. So for iOS we need to register the AUv3 so we can see it now. But we do NOT want to do so if we are
        // running in macOS
        //
        #if os(iOS)
        let bundle = Bundle(for: AudioUnitManager.self)
        AUAudioUnit.registerSubclass(FilterAudioUnit.self, as: componentDescription, name: bundle.auBaseName,
                                     version: UInt32.max)
        #endif

        let componentManager = AVAudioUnitComponentManager.shared();
        let center = NotificationCenter.default
        let mainQueue = OperationQueue.main
        var token: NSObjectProtocol?
        token = center.addObserver(forName: AVAudioUnitComponentManager.registrationsChangedNotification,
                                   object: nil, queue: mainQueue) { notification in
            let found = componentManager.components(matching: componentDescription)
            if !found.isEmpty {
                center.removeObserver(token!)
                self.instantiate(componentDescription: componentDescription)
            }
        }
    }

    private func createAudioUnit2(componentDescription: AudioComponentDescription, viewController: FilterViewController) {
        os_log(.info, log: log, "createAudioUnit")
        componentDescription.log(log, type: .info)

        // Uff. So for iOS we need to register the AUv3 so we can see it now. But we do NOT want to do so if we are
        // running in macOS
        //
        #if os(iOS)
        let bundle = Bundle(for: AudioUnitManager.self)
        AUAudioUnit.registerSubclass(FilterAudioUnit.self, as: componentDescription, name: bundle.auBaseName,
                                     version: UInt32.max)
        let options = AudioComponentInstantiationOptions()
        #endif

        // If we are running in macOS we must load the AUv3 in-process in order to be able to use it from within the
        // app sandbox.
        //
        #if os(macOS)
        let options: AudioComponentInstantiationOptions = .loadInProcess
        #endif

        AVAudioUnit.instantiate(with: componentDescription, options: options) { avAudioUnit, error in
            guard error == nil, let avAudioUnit = avAudioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }
            self.wireAudioUnit(avAudioUnit, viewController: viewController)
        }
    }
    private func instantiate(componentDescription: AudioComponentDescription) {

        // AVAudioUnitComponentManager.registrationsChangedNotification
        // If we are running in macOS we must load the AUv3 in-process in order to be able to use it from within the
        // app sandbox.
        //
        #if os(macOS)
        let options: AudioComponentInstantiationOptions = .loadInProcess
        #else
        let options = AudioComponentInstantiationOptions()
        #endif

        AVAudioUnit.instantiate(with: componentDescription, options: options) { avAudioUnit, error in
            guard error == nil, let avAudioUnit = avAudioUnit else {
                fatalError("Could not instantiate audio unit: \(String(describing: error))")
            }
            os_log(.info, log: self.log, "created AVAudioUnit")
            DispatchQueue.main.async {
                os_log(.info, log: self.log, "requesting view controller")
                avAudioUnit.auAudioUnit.requestViewController { controller in
                    guard let viewController = controller as? FilterViewController else {
                        os_log(.info, log: self.log, "Did not get FilterViewController")
                        return
                    }
                    os_log(.info, log: self.log, "done")
                    self.wireAudioUnit(avAudioUnit, viewController: viewController)
                }
            }
        }
    }

    private func wireAudioUnit(_ avAudioUnit: AVAudioUnit, viewController: FilterViewController) {
        self._viewController = viewController
        guard let auAudioUnit = avAudioUnit.auAudioUnit as? FilterAudioUnit else {
            fatalError("avAudioUnit.auAudioUnit is nil or wrong type")
        }
        auAudioUnit.viewController = viewController
        viewController.audioUnit = auAudioUnit
        playEngine.connectEffect(audioUnit: avAudioUnit)
        signalConnected()
    }

    private func signalConnected() {
        if _viewController?.audioUnit != nil {
            DispatchQueue.main.async { self.delegate?.connected() }
        }
    }

    private static func loadViewController(appExtension: String) -> FilterViewController {
        os_log(.info, log: log, "loadViewController - %{public}s", appExtension)
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent(appExtension) else {
            fatalError("Could not obtain extension bundle URL")
        }

        os_log(.info, log: log, "path: %{public}s", url.path)
        guard let extensionBundle = Bundle(url: url) else { fatalError("Could not get app extension bundle") }

        #if os(iOS)

        let storyboard = Storyboard(name: "MainInterface", bundle: extensionBundle)
        guard let controller = storyboard.instantiateInitialViewController() as? FilterViewController else {
            fatalError("Unable to instantiate FilterViewController")
        }
        return controller

        #elseif os(macOS)

        os_log(.info, log: log, "creating new FilterViewController")
        let viewController = FilterViewController(nibName: "FilterViewController", bundle: extensionBundle)
        os_log(.info, log: log, "done")
        return viewController

        #endif
    }
}

public extension AudioUnitManager {

    /**
     Start/stop audio engine

     - returns: true if playing
     */
    @discardableResult
    func togglePlayback() -> Bool { playEngine.startStop() }

    /**
     The world is being torn apart. Stop any asynchronous eventing from happening in the future.
     */
    func cleanup() {
        playEngine.stop()
    }
}
