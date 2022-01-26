// Copyright © 2021 Brad Howes. All rights reserved.

import AUv3Support
import CoreAudioKit
import Cocoa
import AVFAudio
import os.log

final class MainViewController: NSViewController {
  private var log: OSLog!

  private var audioUnitLoader: AudioUnitLoader!
  private var userPresetsManager: UserPresetsManager?
  private var presetsMenuManager: PresetsMenuManager?

  private var avAudioUnit: AVAudioUnit?
  private var auAudioUnit: AUAudioUnit? { avAudioUnit?.auAudioUnit }
  private var audioUnitViewController: NSViewController?

  private var playButton: NSButton!
  private var bypassButton: NSButton!
  private var presetsButton: NSPopUpButton!

  private var playMenuItem: NSMenuItem!
  private var bypassMenuItem: NSMenuItem!
  private var presetsMenu: NSMenu!
  
  @IBOutlet weak var containerView: NSView!
  @IBOutlet weak var loadingText: NSTextField!
  
  private var windowController: MainWindowController? { view.window?.windowController as? MainWindowController }
  private var appDelegate: AppDelegate? { NSApplication.shared.delegate as? AppDelegate }
  
  private var filterView: NSView?
  private var parameterTreeObserverToken: AUParameterObserverToken?
  private var allParameterValuesObserverToken: NSKeyValueObservation?

}

// MARK: - View Management
extension MainViewController {
  
  override func viewDidLoad() {
    super.viewDidLoad()
    let bundle = Bundle.main
    let audioUnitName = bundle.auBaseName

    Shared.loggingSubsystem = audioUnitName
    log = Shared.logger("MainViewController")

    let component = AudioComponentDescription(componentType: bundle.auComponentType,
                                              componentSubType: bundle.auComponentSubtype,
                                              componentManufacturer: bundle.auComponentManufacturer,
                                              componentFlags: 0, componentFlagsMask: 0)

    audioUnitLoader = .init(name: audioUnitName, componentDescription: component, loop: .sample1)
    audioUnitLoader.delegate = self
  }
  
  override func viewWillAppear() {
    super.viewWillAppear()
    guard let appDelegate = appDelegate,
          let windowController = windowController else {
      fatalError()
    }
    
    view.window?.delegate = self
    presetsMenu = appDelegate.presetsMenu
    guard presetsMenu != nil else { fatalError() }
    
    playMenuItem = appDelegate.playMenuItem
    bypassMenuItem = appDelegate.bypassMenuItem
    bypassMenuItem.isEnabled = false

    playButton = windowController.playButton
    bypassButton = windowController.bypassButton
    bypassButton.isEnabled = false

    presetsButton = windowController.presetsButton
    presetsButton.isEnabled = false
  }
  
  override func viewDidLayout() {
    super.viewDidLayout()
    filterView?.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: containerView.frame.size)
  }
  
  override func viewDidAppear() {
    super.viewDidAppear()
    let showedAlertKey = "showedInitialAlert"
    guard UserDefaults.standard.bool(forKey: showedAlertKey) == false else { return }
    UserDefaults.standard.set(true, forKey: showedAlertKey)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "AUv3 Component Installed"
    alert.informativeText =
      """
The AUv3 component 'SimplyFlange' is now available on your device and can be used in other AUv3 host apps such as GarageBand and Logic.

You can continue to use this app to experiment, but you do not need to have it running in order to access the AUv3 component in other apps.

If you delete this app from your device, the AUv3 component will no longer be available for use in other host applications.
"""
    alert.addButton(withTitle: "OK")
    alert.beginSheetModal(for: view.window!){ _ in }
  }
}

extension MainViewController: AudioUnitLoaderDelegate {

  public func connected(audioUnit: AVAudioUnit, viewController: NSViewController) {
    os_log(.debug, log: log, "connected BEGIN")
    let userPresetsManager = UserPresetsManager(for: audioUnit.auAudioUnit)
    self.userPresetsManager = userPresetsManager

    let presetsMenuManager = PresetsMenuManager(button: presetsButton, appMenu: presetsMenu,
                                                userPresetsManager: userPresetsManager)
    self.presetsMenuManager = presetsMenuManager
    presetsMenuManager.build()

    avAudioUnit = audioUnit
    audioUnitViewController = viewController
    connectFilterView(audioUnit, viewController)
    connectParametersToControls(audioUnit.auAudioUnit)
    os_log(.debug, log: log, "connected END")
  }

  public func failed(error: AudioUnitLoaderError) {
    os_log(.error, log: log, "failed BEGIN - error: %{public}s", error.description)
    let message = "Unable to load the AUv3 component. \(error.description)"
    notify(title: "AUv3 Failure", message: message)
    os_log(.debug, log: log, "failed END")
  }
}

extension MainViewController {
  
  @IBAction private func togglePlay(_ sender: NSButton) {
    audioUnitLoader.togglePlayback()
    playButton?.state = audioUnitLoader.isPlaying ? .on : .off

    playMenuItem?.title = audioUnitLoader.isPlaying ? "Stop" : "Play"
    bypassButton?.isEnabled = audioUnitLoader.isPlaying
    bypassMenuItem?.isEnabled = audioUnitLoader.isPlaying
  }
  
  @IBAction private func toggleBypass(_ sender: NSButton) {
    let wasBypassed = auAudioUnit?.shouldBypassEffect ?? false
    let isBypassed = !wasBypassed
    auAudioUnit?.shouldBypassEffect = isBypassed
    bypassButton?.state = isBypassed ? .on : .off
    bypassMenuItem?.title = isBypassed ? "Resume" : "Bypass"
  }
}

extension MainViewController: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    audioUnitLoader.cleanup()
    guard let parameterTree = auAudioUnit?.parameterTree,
          let parameterTreeObserverToken = parameterTreeObserverToken else { return }
    parameterTree.removeParameterObserver(parameterTreeObserverToken)
  }
}

extension MainViewController {
  
  private func connectFilterView(_ audioUnit: AVAudioUnit, _ viewController: NSViewController) {
    os_log(.debug, log: log, "connectFilterView BEGIN")
    containerView.addSubview(viewController.view)
    viewController.view.pinToSuperviewEdges()

    addChild(viewController)
    view.needsLayout = true
    containerView.needsLayout = true

    playButton.isEnabled = true
    presetsButton.isEnabled = true

    os_log(.debug, log: log, "connectFilterView END")
  }

  public func connectParametersToControls(_ audioUnit: AUAudioUnit) {
    os_log(.debug, log: log, "connectParametersToControls BEGIN")
    guard let parameterTree = audioUnit.parameterTree else {
      fatalError("FilterAudioUnit does not define any parameters.")
    }

    audioUnitLoader.restore()

    allParameterValuesObserverToken = audioUnit.observe(\.allParameterValues) { [weak self] _, _ in
      guard let self = self else { return }
      os_log(.debug, log: self.log, "allParameterValues changed")
      DispatchQueue.main.async { self.updateView() }
    }

    parameterTreeObserverToken = parameterTree.token(byAddingParameterObserver: { [weak self] address, _ in
      guard let self = self else { return }
      os_log(.debug, log: self.log, "parameterTree changed - %d", address)
      DispatchQueue.main.async { self.updateView() }
    })

    os_log(.debug, log: log, "connectParametersToControls END")
  }

  public func usePreset(number: Int) {
    os_log(.debug, log: log, "usePreset BEGIN")
    guard let userPresetManager = userPresetsManager else { return }
    userPresetManager.makeCurrentPreset(number: number)
    updatePresetMenu()
    os_log(.debug, log: log, "usePreset BEGIN")
  }

  func updatePresetMenu() {
    os_log(.debug, log: log, "updatePresetMenu BEGIN")
    presetsMenuManager?.selectActive()
    os_log(.debug, log: log, "updatePresetMenu END")
  }

  private func updateView() {
    os_log(.debug, log: log, "updateView BEGIN")
    updatePresetMenu()
    audioUnitLoader.save()
    os_log(.debug, log: log, "updateView END")
  }
}

// MARK: - Alerts and Prompts

extension MainViewController {

  public func notify(title: String, message: String) {
    let controller = NSAlert()
    controller.alertStyle = .critical
    controller.informativeText = title
    controller.messageText = message
    controller.addButton(withTitle: "OK")
    DispatchQueue.main.async { controller.runModal() }
  }

  public func yesOrNo(title: String, message: String, continuation: @escaping (Bool) -> Void) {

    let controller = NSAlert()
    controller.informativeText = title
    controller.messageText = message
    controller.addButton(withTitle: "Continue")
    controller.addButton(withTitle: "Cancel")
    DispatchQueue.main.async {
      let outcome = controller.runModal()
      continuation(outcome == .OK)
    }
  }
}
