// Copyright © 2022 Brad Howes. All rights reserved.

import Foundation
import Kernel

/**
 Protocol for objects that can hold tag values. Useful for mapping from UI elements to specific parameters.
 */
public protocol TagHolder: NSObject {
  var tag: Int { get set }
}

public extension TagHolder {

  /**
   Store a parameter address in the tag attribute.

   - parameter address: the value to store
   */
  func setParameterAddress(_ address: ParameterAddress) { tag = Int(address.rawValue) }

  /**
   Obtain the parameter address found in the tag attribute.

   - returns optional `ParameterAddress` value.
   */
  var parameterAddress: ParameterAddress? { ParameterAddress(rawValue: UInt64(tag) ) }
}
