// Copyright (c) 2023 Tom Sutcliffe
// See LICENSE file for license information.

import XCTest
import Tilt

final class TiltTests: XCTestCase {
    var env: TiltEnvironment! = nil

    override func setUpWithError() throws {
        env = TiltEnvironment()
        env.L.addModules(lua_sources)
    }

    override func tearDownWithError() throws {
        env = nil
    }

    func test_templater_tests() throws -> Void {
        try env.L.globals["require"]("templater_tests")
    }
}
