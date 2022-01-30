// Copyright © 2021 Brad Howes. All rights reserved.

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var playMenuItem: NSMenuItem!
  @IBOutlet weak var bypassMenuItem: NSMenuItem!
  @IBOutlet weak var presetsMenu: NSMenu!
  
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  
  var appStoreUrl: URL {
    let appStoreId = Bundle.main.appStoreId
    return URL(string: "https://itunes.apple.com/app/id\(appStoreId)")!
  }
  
  func visitAppStore() {
    NSWorkspace.shared.open(appStoreUrl)
  }
}
