// Copyright © 2021 Brad Howes. All rights reserved.

import XCTest
import SimplyFlangeFramework

extension Bundle {
    func info(for key: String) -> String { infoDictionary?[key] as! String }
    var auBaseName: String { info(for: "AU_BASE_NAME") }
    var auComponentName: String { info(for: "AU_COMPONENT_NAME") }
    var auComponentType: String { info(for: "AU_COMPONENT_TYPE") }
    var auComponentSubtype: String { info(for: "AU_COMPONENT_SUBTYPE") }
    var auComponentManufacturer: String { info(for: "AU_COMPONENT_MANUFACTURER") }
    var auFactoryFunction: String { info(for: "AU_FACTORY_FUNCTION") }
    var appStoreId: String { info(for: "APP_STORE_ID") }
}

class BundlePropertiesTests: XCTestCase {

    func testComponentAttributes() throws {
        let bundle = Bundle(for: SimplyFlangeFramework.FilterAudioUnit.self)
        XCTAssertEqual("SimplyFlange", bundle.auBaseName)
        XCTAssertEqual("B-Ray: SimplyFlange", bundle.auComponentName)
        XCTAssertEqual("aufx", bundle.auComponentType)
        XCTAssertEqual("flng", bundle.auComponentSubtype)
        XCTAssertEqual("BRay", bundle.auComponentManufacturer)
        XCTAssertEqual("SimplyFlangeFramework.FilterViewController", bundle.auFactoryFunction)
        XCTAssertEqual("1554960150", bundle.appStoreId)
    }
}
