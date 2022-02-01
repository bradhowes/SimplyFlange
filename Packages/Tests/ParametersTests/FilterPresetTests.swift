import XCTest
@testable import Parameters

final class AudioUnitParametersTests: XCTestCase {

  func testInit() throws {
    
    let a = FilterPreset(depth: 1.0, rate: 2.0, delay: 3.0, feedback: 4.0, dryMix: 5.0, wetMix: 6.0,
                         negativeFeedback: 1.0, odd90: 0.0)

    XCTAssertEqual(a.depth, 1.0)
    XCTAssertEqual(a.rate, 2.0)
    XCTAssertEqual(a.delay, 3.0)
    XCTAssertEqual(a.feedback, 4.0)
    XCTAssertEqual(a.dryMix, 5.0)
    XCTAssertEqual(a.wetMix, 6.0)
    XCTAssertEqual(a.negativeFeedback, 1.0)
    XCTAssertEqual(a.odd90, 0.0)
  }
}
