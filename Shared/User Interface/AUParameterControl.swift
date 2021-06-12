// Copyright © 2021 Brad Howes. All rights reserved.

import CoreAudioKit
import os

protocol AUParameterControl {
  
  var control: NSObject { get }
  
  var parameter: AUParameter { get }
  
  func controlChanged()
  
  func parameterChanged()
  
  func setEditedValue(_ value: AUValue)
}
