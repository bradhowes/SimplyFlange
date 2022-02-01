// Copyright © 2021 Brad Howes. All rights reserved.

// NOTE: the source of the ParameterAddress enum is defined in the Adapter.h file in the Kernel. Better would be to
// define it as a Swift enum, but 

import AudioUnit
import AUv3Support
import ParameterAddress

extension ParameterAddress: ParameterAddressProvider {
  public var parameterAddress: AUParameterAddress { UInt64(self.rawValue) }
}
