import XCTest
@testable import Parameters
import Kernel

class SomeObject: NSObject, TagHolder {
  var tag: Int = 0
}

final class TagHolderTests: XCTestCase {
  func testAPI() throws {
    let a = SomeObject()
    XCTAssertEqual(a.tag, 0)

    a.setParameterAddress(.feedback)
    XCTAssertEqual(a.tag, Int(ParameterAddress.feedback.rawValue))
    XCTAssertEqual(a.parameterAddress, .feedback)

    a.tag = -1;
    XCTAssertEqual(a.parameterAddress, nil)
  }
}
