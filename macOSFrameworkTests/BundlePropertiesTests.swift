// Copyright © 2020 Brad Howes. All rights reserved.

import XCTest
import SimplyFlangerFilterFramework

extension Bundle {
    func info(for key: String) -> String { infoDictionary?[key] as! String }
    var auBaseName: String { info(for: "AU_BASE_NAME") }
    var auComponentName: String { info(for: "AU_COMPONENT_NAME") }
    var auComponentType: String { info(for: "AU_COMPONENT_TYPE") }
    var auComponentSubtype: String { info(for: "AU_COMPONENT_SUBTYPE") }
    var auComponentManufacturer: String { info(for: "AU_COMPONENT_MANUFACTURER") }
    var auFactoryFunction: String { info(for: "AU_FACTORY_FUNCTION") }
}

class BundlePropertiesTests: XCTestCase {

    func testComponentAttributes() throws {
        let bundle = Bundle(for: SimplyFlangerFilterFramework.FilterAudioUnit.self)
        XCTAssertEqual("SimplyFlanger", bundle.auBaseName)
        XCTAssertEqual("B-Ray: SimplyFlanger", bundle.auComponentName)
        XCTAssertEqual("aufx", bundle.auComponentType)
        XCTAssertEqual("flng", bundle.auComponentSubtype)
        XCTAssertEqual("BRay", bundle.auComponentManufacturer)
        XCTAssertEqual("SimplyFlangerFilterFramework.FilterViewController", bundle.auFactoryFunction)
    }
}
