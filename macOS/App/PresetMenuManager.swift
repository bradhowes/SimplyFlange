// Copyright © 2021 Brad Howes. All rights reserved.

import Cocoa
import AUv3Support
import os.log
import AudioToolbox

enum UserMenuItem: Int {
  case save
  case rename
  case delete
}

class PresetsMenuManager: NSObject {
  private let noCurrentPreset = Int.max
  private let commandTag = Int.max - 1

  private let button: NSPopUpButton
  private let appMenu: NSMenu
  private let userPresetsManager: UserPresetsManager

  init(button: NSPopUpButton, appMenu: NSMenu, userPresetsManager: UserPresetsManager) {
    self.button = button
    self.appMenu = appMenu
    self.userPresetsManager = userPresetsManager
    super.init()
  }

  @IBAction func handlePresetMenuSelection(_ sender: NSMenuItem) {
    userPresetsManager.makeCurrentPreset(number: sender.tag)
    appMenu.items.forEach { $0.state = .off }
    sender.state = .on
  }

  @IBAction func savePreset(_ sender: NSMenuItem) {
    guard let presetName = getPresetName(default: "Preset \(-userPresetsManager.nextNumber)") else { return }
    try? userPresetsManager.create(name: presetName)
    build()
  }

  @IBAction func renamePreset(_ sender: NSMenuItem) {
    guard let activePreset = userPresetsManager.currentPreset else { fatalError() }
    guard let presetName = getPresetName(default: activePreset.name) else { return }
    try? userPresetsManager.renameCurrent(to: presetName)
    build()
  }

  @IBAction func deletePreset(_ sender: NSMenuItem) {
    try? userPresetsManager.deleteCurrent()
    build()
  }

  func selectActive() {
    let activeNumber = userPresetsManager.audioUnit.currentPreset?.number ?? noCurrentPreset
    refreshUserPresetsMenu(appMenu.items[0].submenu, activeNumber: activeNumber)
    refreshFactoryPresetsMenu(appMenu.items[1].submenu, activeNumber: activeNumber)
    refreshUserPresetsMenu(button.menu?.items[1].submenu, activeNumber: activeNumber)
    refreshFactoryPresetsMenu(button.menu?.items[2].submenu, activeNumber: activeNumber)
  }

  func build() {
    guard let buttonMenu = button.menu else { fatalError() }

    populateUserPresetsMenu(appMenu.items[0].submenu!)
    populateFactoryPresetsMenu(appMenu.items[1].submenu!)
    populateUserPresetsMenu(buttonMenu.items[1].submenu!)
    populateFactoryPresetsMenu(buttonMenu.items[2].submenu!)
  }

  private func populateFactoryPresetsMenu(_ menu: NSMenu) {
    menu.removeAllItems()
    userPresetsManager.audioUnit.factoryPresetsNonNil.forEach { preset in
      let item = NSMenuItem(title: preset.name, action: #selector(handlePresetMenuSelection), keyEquivalent: "")
      item.target = self
      item.tag = preset.number
      menu.addItem(item)
    }
  }

  private func populateUserPresetsMenu(_ menu: NSMenu) {
    menu.removeAllItems()
    menu.addItem(withTitle: "Save", action: #selector(savePreset(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "Rename", action: #selector(renamePreset(_:)), keyEquivalent: "")
    menu.addItem(withTitle: "Delete", action: #selector(deletePreset(_:)), keyEquivalent: "")

    menu.items.forEach { item in
      item.target = self
      item.tag = commandTag
      item.state = .off
      item.isEnabled = false
    }

    if !userPresetsManager.presets.isEmpty {
      menu.addItem(.separator())
    }

    userPresetsManager.presets.forEach { preset in
      let item = NSMenuItem(title: preset.name, action: #selector(handlePresetMenuSelection), keyEquivalent: "")
      item.target = self
      item.tag = preset.number
      menu.addItem(item)
    }
  }

  private func refreshUserPresetsMenu(_ menu: NSMenu?, activeNumber: Int) {
    guard let menu = menu else { return }

    menu.items[.save].isEnabled = true
    menu.items[.rename].isEnabled = activeNumber < 0
    menu.items[.delete].isEnabled = activeNumber < 0

    menu.items.forEach { item in
      item.state = item.tag == activeNumber ? .on : .off
    }
  }

  private func refreshFactoryPresetsMenu(_ menu: NSMenu?, activeNumber: Int) {
    guard let menu = menu else { return }
    menu.items.forEach { item in
      item.state = item.tag == activeNumber ? .on : .off
    }
  }

  private func getPresetName(default: String) -> String? {
    let prompt = NSAlert()

    prompt.addButton(withTitle: "OK")
    prompt.buttons.last?.tag = NSApplication.ModalResponse.OK.rawValue

    prompt.addButton(withTitle: "Cancel")
    prompt.buttons.last?.tag = NSApplication.ModalResponse.cancel.rawValue

    prompt.messageText = "Preset Name"
    prompt.informativeText = "Enter the name to use for the preset"

    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    textField.stringValue = `default`
    prompt.accessoryView = textField
    let response: NSApplication.ModalResponse = prompt.runModal()

    if response == .OK {
      let value = textField.stringValue.trimmingCharacters(in: .whitespaces)
      return value.isEmpty ? nil : value
    } else {
      return nil
    }
  }
}

private extension Array where Element == NSMenuItem {
  subscript(_ index: UserMenuItem) -> NSMenuItem {
    self[index.rawValue]
  }
}
