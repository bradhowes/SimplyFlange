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

  private var avAudioUnit: AVAudioUnit?
  private var auAudioUnit: AUAudioUnit? { avAudioUnit?.auAudioUnit }
  private var audioUnitViewController: NSViewController?

  private var playButton: NSButton!
  private var bypassButton: NSButton!
  private var playMenuItem: NSMenuItem!
  private var bypassMenuItem: NSMenuItem!
  private var savePresetMenuItem: NSMenuItem!
  
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
    savePresetMenuItem = appDelegate.savePresetMenuItem
    guard savePresetMenuItem != nil else { fatalError() }
    
    playButton = windowController.playButton
    playMenuItem = appDelegate.playMenuItem
    
    bypassButton = windowController.bypassButton
    bypassMenuItem = appDelegate.bypassMenuItem
    bypassButton.isEnabled = false
    bypassMenuItem.isEnabled = false
    
    savePresetMenuItem.isHidden = true
    savePresetMenuItem.isEnabled = false
    savePresetMenuItem.target = self
    savePresetMenuItem.action = #selector(handleSavePresetMenuSelection(_:))
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
    userPresetsManager = .init(for: audioUnit.auAudioUnit)
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
    playButton?.title = audioUnitLoader.isPlaying ? "Stop" : "Play"
    playMenuItem?.title = audioUnitLoader.isPlaying ? "Stop" : "Play"
    bypassButton?.isEnabled = audioUnitLoader.isPlaying
    bypassMenuItem?.isEnabled = audioUnitLoader.isPlaying
  }
  
  @IBAction private func toggleBypass(_ sender: NSButton) {
    let wasBypassed = auAudioUnit?.shouldBypassEffect ?? false
    let isBypassed = !wasBypassed
    auAudioUnit?.shouldBypassEffect = isBypassed
    bypassButton?.state = isBypassed ? .on : .off
    bypassButton?.title = isBypassed ? "Resume" : "Bypass"
    bypassMenuItem?.title = isBypassed ? "Resume" : "Bypass"
  }

  private func getPresetName(default: String) -> String? {
    let prompt = NSAlert()
    prompt.addButton(withTitle: "Continue")
    prompt.addButton(withTitle: "Cancel")
    prompt.messageText = "New Preset Name"
    prompt.informativeText = "Enter the name to use for the new preset"

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    textField.stringValue = `default`
    prompt.accessoryView = textField
    let response: NSApplication.ModalResponse = prompt.runModal()

    if response == .OK {
      return textField.stringValue.trimmingCharacters(in: .whitespaces)
    } else {
      return nil
    }
  }

  @objc private func handleSavePresetMenuSelection(_ sender: NSMenuItem) throws {
    guard let userPresetsManager = userPresetsManager else { return }
    guard let presetMenu = NSApplication.shared.mainMenu?.item(withTag: 666)?.submenu else { return }

    let index = userPresetsManager.nextNumber
    let defaultName = "Preset \(index)"

    guard
      let name = getPresetName(default: defaultName),
      !name.isEmpty
    else {
      return
    }

    var preset: AUAudioUnitPreset!
    do {
      preset = try userPresetsManager.create(name: name)
    } catch {
      print(error.localizedDescription)
      return
    }

    let menuItem = NSMenuItem(title: preset.name,
                              action: #selector(handlePresetMenuSelection(_:)),
                              keyEquivalent: "")
    menuItem.tag = preset.number
    presetMenu.addItem(menuItem)
  }
  
  @objc private func handlePresetMenuSelection(_ sender: NSMenuItem) {
    guard let audioUnit = auAudioUnit else { return }
    sender.menu?.items.forEach { $0.state = .off }
    if sender.tag >= 0 {
      audioUnit.currentPreset = audioUnit.factoryPresetsNonNil[sender.tag]
    }
    else {
      audioUnit.currentPreset = audioUnit.userPresets[sender.tag]
    }
    
    sender.state = .on
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
    // presetSelection.isEnabled = true
    // userPresetsMenuButton.isEnabled = true

//    let presetCount = auAudioUnit?.factoryPresetsNonNil.count ?? 0
//    while presetSelection.numberOfSegments < presetCount {
//      let index = presetSelection.numberOfSegments + 1
//      presetSelection.insertSegment(withTitle: "\(index)", at: index - 1, animated: false)
//    }
//    while presetSelection.numberOfSegments > presetCount {
//      presetSelection.removeSegment(at: presetSelection.numberOfSegments - 1, animated: false)
//    }

//    presetSelection.selectedSegmentIndex = 0
    // useFactoryPreset(nil)
    os_log(.debug, log: log, "connectFilterView END")
  }

  public func connectParametersToControls(_ audioUnit: AUAudioUnit) {
    os_log(.debug, log: log, "connectParametersToControls BEGIN")
    guard let parameterTree = audioUnit.parameterTree else {
      fatalError("FilterAudioUnit does not define any parameters.")
    }

    audioUnitLoader.restore()
    updatePresetMenu()

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
//    guard let userPresetsManager = userPresetsManager else {
//      os_log(.debug, log: log, "updatePresetMenu END - nil userPresetsManager")
//      return
//    }
//
//    let active = userPresetsManager.audioUnit.currentPreset?.number ?? Int.max
//
//    let factoryPresets = userPresetsManager.audioUnit.factoryPresetsNonNil.map { (preset: AUAudioUnitPreset) -> UIAction in
//      let action = UIAction(title: preset.name, handler: { _ in self.usePreset(number: preset.number) })
//      action.state = active == preset.number ? .on : .off
//      return action
//    }
//
//    os_log(.debug, log: log, "updatePresetMenu - adding %d factory presets", factoryPresets.count)
//    let factoryPresetsMenu = UIMenu(title: "Factory", options: .displayInline, children: factoryPresets)
//
//    let userPresets = userPresetsManager.presetsOrderedByName.map { (preset: AUAudioUnitPreset) -> UIAction in
//      let action = UIAction(title: preset.name, handler: { _ in self.usePreset(number: preset.number) })
//      action.state = active == preset.number ? .on : .off
//      return action
//    }
//
//    os_log(.debug, log: log, "updatePresetMenu - adding %d user presets", userPresets.count)
//
//    let userPresetsMenu = UIMenu(title: "User", options: .displayInline, children: userPresets)
//
//    let actionsGroup = UIMenu(title: "Actions", options: .displayInline,
//                              children: active < 0 ? [saveAction, renameAction, deleteAction] : [saveAction])
//
//    let menu = UIMenu(title: "Presets", options: [], children: [userPresetsMenu, factoryPresetsMenu, actionsGroup])
//
//    if #available(iOS 14, *) {
//      userPresetsMenuButton.menu = menu
//      userPresetsMenuButton.showsMenuAsPrimaryAction = true
//    }

    os_log(.debug, log: log, "updatePresetMenu END")
  }

  private func updateView() {
    os_log(.debug, log: log, "updateView BEGIN")
    guard let auAudioUnit = auAudioUnit else { return }
    updatePresetMenu()
    updatePresetSelection(auAudioUnit)
    audioUnitLoader.save()
    os_log(.debug, log: log, "updateView END")
  }

  private func updatePresetSelection(_ auAudioUnit: AUAudioUnit) {
    os_log(.debug, log: log, "updatePresetSelection BEGIN")
//    if let presetNumber = auAudioUnit.currentPreset?.number {
//      os_log(.info, log: log, "updatePresetSelection: %d", presetNumber)
//      presetSelection.selectedSegmentIndex = presetNumber
//      presetName.text = auAudioUnit.currentPreset?.name
//    } else {
//      presetSelection.selectedSegmentIndex = -1
//    }
    os_log(.debug, log: log, "updatePresetSelection END")
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
