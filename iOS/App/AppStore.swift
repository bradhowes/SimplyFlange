// Copyright © 2021 Brad Howes. All rights reserved.

import UIKit

public struct AppStore {
  
  static var appStoreUrl: URL {
    let appStoreId = Bundle.main.appStoreId
    let url = "https://apps.apple.com/app/id\(appStoreId)"
    return URL(string: url)!
  }
  
  static var reviewUrl: URL {
    let appStoreId = Bundle.main.appStoreId
    let url = "https://apps.apple.com/app/id\(appStoreId)?action=write-review"
    return URL(string: url)!
  }
  
  static var supportUrl: URL {
    return URL(string: "https://github.com/bradhowes/SimplyFlange")!
  }
  
  static func visitAppStore() {
    UIApplication.shared.open(appStoreUrl, options: [:], completionHandler: nil)
  }
  
  static func reviewApp() {
    UIApplication.shared.open(reviewUrl, options: [:], completionHandler: nil)
  }
  
  static func visitSupportUrl() {
    UIApplication.shared.open(supportUrl, options: [:], completionHandler: nil)
  }
}

