//
//  ViewConfigurationManager.swift
//  macOS Extension
//
//  Created by Brad Howes on 29/01/2022.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import CoreAudioKit

extension FilterViewController: AudioUnitViewConfigurationManager {

  public func supportedViewConfigurations(_ available: [AUAudioUnitViewConfiguration]) -> IndexSet {
    var indexSet = IndexSet()
    for (index, viewConfiguration) in available.enumerated() {
      if viewConfiguration.width > 0 && viewConfiguration.height > 0 {
        indexSet.insert(index)
      }
    }
    return indexSet
  }

  public func selectViewConfiguration(_ viewConfiguration: AUAudioUnitViewConfiguration) {
    
  }
}
