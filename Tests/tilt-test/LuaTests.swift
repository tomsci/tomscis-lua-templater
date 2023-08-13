//
//  LuaTests.swift
//  Tilt
//
//  Created by Tom Sutcliffe on 11/08/2023.
//

import XCTest
import Tilt
import TiltC

fileprivate func dummyFn(_ L: LuaState!) -> CInt {
    return 0
}

final class LuaTests: XCTestCase {

    var L: LuaState!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        if let L {
            L.close()
        }
        L = nil
    }

//    func testExample() throws {
//        // This is an example of a functional test case.
//        // Use XCTAssert and related functions to verify your tests produce the correct results.
//        // Any test you write for XCTest can be annotated as throws and async.
//        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
//        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
//    }

    func testSafeLibraries() {
        L = LuaState(libraries: .safe)
        let unsafeLibs = ["os", "io", "package", "debug"]
        for lib in unsafeLibs {
            let t = L.getglobal(lib)
            XCTAssertEqual(t, .nilType)
            L.pop()
        }
        XCTAssertEqual(L.gettop(), 0)
    }

    func testPcall() throws {
        L = LuaState(libraries: [])
        L.getglobal("type")
        L.push(123)
        try L.pcall(nargs: 1, nret: 1)
        XCTAssertEqual(L.gettop(), 1)
        XCTAssertEqual(L.tostring(-1), "number")
        L.pop()
    }

    func testPcallThrow() throws {
        L = LuaState(libraries: [])
        var expectedErr: LuaCallError? = nil
        do {
            L.getglobal("error")
            try L.pcall(arguments: "Deliberate error", traceback: false)
        } catch let error as LuaCallError {
            expectedErr = error
        }
        XCTAssertNotEqual(expectedErr, nil)
        XCTAssertEqual(expectedErr!.error, "Deliberate error")
    }

    func testToInt() {
        L = LuaState(libraries: [])
        L.push(1234) // 1
        L.push(true) // 2
        L.push("hello") // 3
        L.push(123.456) // 4
        L.pushnil() // 5
        L.push(dummyFn) // 6
        XCTAssertEqual(L.toint(1), 1234)
        XCTAssertEqual(L.toint(2), nil)
        XCTAssertEqual(L.toint(3), nil)
        XCTAssertEqual(L.toint(4), nil)
        XCTAssertEqual(L.toint(5), nil)
        XCTAssertEqual(L.toint(6), nil)
    }

    func testToNumber() {
        L = LuaState(libraries: [])
        L.push(1234) // 1
        L.push(true) // 2
        L.push("hello") // 3
        L.push(123.456) // 4
        L.pushnil() // 5
        L.push(dummyFn) // 6
        XCTAssertEqual(L.tonumber(1), 1234)
        XCTAssertEqual(L.tonumber(2), nil)
        XCTAssertEqual(L.tonumber(3), nil)
        XCTAssertEqual(L.tonumber(4), 123.456)
        XCTAssertEqual(L.tonumber(5), nil)
        XCTAssertEqual(L.toint(6), nil)
    }

    func testToBool() {
        L = LuaState(libraries: [])
        L.push(1234) // 1
        L.push(true) // 2
        L.push(false) // 3
        L.pushnil() // 4
        L.push(dummyFn) // 5
        XCTAssertEqual(L.toboolean(1), true)
        XCTAssertEqual(L.toboolean(2), true)
        XCTAssertEqual(L.toboolean(3), false)
        XCTAssertEqual(L.toboolean(4), false)
        XCTAssertEqual(L.toboolean(5), true)
    }

    func testToString() {
        L = LuaState(libraries: [])
        L.push("Hello")
        L.push("A ü†ƒ8 string", encoding: .utf8)
        L.push(1234)
        L.push("îsø", encoding: .isoLatin1)

        XCTAssertEqual(L.tostring(1, encoding: .utf8, convert: false), "Hello")
        XCTAssertEqual(L.tostring(2, encoding: .utf8, convert: false), "A ü†ƒ8 string")
        XCTAssertEqual(L.tostring(3, encoding: .utf8, convert: false), nil)
        XCTAssertEqual(L.tostring(3, encoding: .utf8, convert: true), "1234")
        XCTAssertEqual(L.tostring(4, encoding: .utf8, convert: true), nil) // not valid UTF-8
        XCTAssertEqual(L.tostring(4, encoding: .isoLatin1, convert: false), "îsø")

        // TODO how should we handle default encodings?
    }

    func testToAnyHashable() {
        // TODO
    }

    func testIpairs() {
        L = LuaState(libraries: [])
        let arr = [11, 22, 33, 44]
        L.push(arr) // Because Array<Int> conforms to Array<T: Pushable> which is itself Pushable
        var expected: lua_Integer = 0
        for i in L.ipairs(1) {
            expected = expected + 1
            XCTAssertEqual(i, expected)
            XCTAssertEqual(L.gettop(), 2)
            XCTAssertEqual(L.tointeger(2), expected * 11)
        }
        XCTAssertEqual(expected, 4)
        XCTAssertEqual(L.gettop(), 1)

        // Now check that a table with nils in is also handled correctly
        expected = 0
        L.pushnil()
        lua_rawseti(L, -2, 3) // arr[3] = nil
        for i in L.ipairs(1) {
            expected = expected + 1
            XCTAssertEqual(i, expected)
            XCTAssertEqual(L.gettop(), 2)
            XCTAssertEqual(L.tointeger(2), expected * 11)
        }
        XCTAssertEqual(expected, 2)
        XCTAssertEqual(L.gettop(), 1)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
