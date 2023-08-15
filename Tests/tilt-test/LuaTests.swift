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

    func test_pcall() throws {
        L = LuaState(libraries: [])
        L.getglobal("type")
        L.push(123)
        try L.pcall(nargs: 1, nret: 1)
        XCTAssertEqual(L.gettop(), 1)
        XCTAssertEqual(L.tostring(-1), "number")
        L.pop()
    }

    func test_pcall_throw() throws {
        L = LuaState(libraries: [])
        var expectedErr: LuaCallError? = nil
        do {
            L.getglobal("error")
            try L.pcall(arguments: "Deliberate error", traceback: false)
        } catch let error as LuaCallError {
            expectedErr = error
        }
        XCTAssertNotNil(expectedErr)
        XCTAssertEqual(expectedErr!.error, "Deliberate error")
    }

    func test_toint() {
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

    func test_tonumber() {
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

    func test_tobool() {
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

    func test_tostring() {
        L = LuaState(libraries: [])
        L.push("Hello")
        L.push("A ü†ƒ8 string")
        L.push(1234)
        L.push("îsø", encoding: .isoLatin1)

        XCTAssertEqual(L.tostring(1, encoding: .utf8, convert: false), "Hello")
        XCTAssertEqual(L.tostring(2, encoding: .utf8, convert: false), "A ü†ƒ8 string")
        XCTAssertEqual(L.tostring(3, encoding: .utf8, convert: false), nil)
        XCTAssertEqual(L.tostring(3, encoding: .utf8, convert: true), "1234")
        XCTAssertEqual(L.tostring(4, convert: true), nil) // not valid in the default encoding (ie UTF-8)
        XCTAssertEqual(L.tostring(4, encoding: .isoLatin1, convert: false), "îsø")

        L.setDefaultStringEncoding(.stringEncoding(.isoLatin1))
        XCTAssertEqual(L.tostring(4), "îsø") // this should now succeed
    }

    func test_ipairs() {
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

    func test_pairs() {
        L = LuaState(libraries: [])
        var dict = [
            "aaa": 111,
            "bbb": 222,
            "ccc": 333,
        ]
        L.push(dict)
        for (k, v) in L.pairs(1) {
            let key = L.tostring(k)
            let val = L.toint(v)
            XCTAssertNotNil(key)
            XCTAssertNotNil(val)
            let foundVal = dict.removeValue(forKey: key!)
            XCTAssertEqual(val, foundVal)
        }
        XCTAssertTrue(dict.isEmpty) // All entries should have been removed by the pairs loop
    }

    func test_pushuserdata() {
        struct Foo : Equatable {
            let intval: Int
            let strval: String
        }
        L = LuaState(libraries: [])
        L.registerMetatable(for: Foo.self, functions: [:])
        let val = Foo(intval: 123, strval: "abc")
        L.pushuserdata(val)
        XCTAssertEqual(L.type(1), .userdata)

        // Check pushany handles it as a userdata too
        L.pushany(val)
        XCTAssertEqual(L.type(2), .userdata)
        L.pop()

        // Test toany
        let anyval = L.toany(1, guessType: false)
        XCTAssertEqual(anyval as? Foo, val)

        // Test the magic that tovalue does on top of toany
        let valFromLua: Foo? = L.tovalue(1)
        XCTAssertEqual(valFromLua, val)

        L.pop()
    }

    // Tests that objects deinit correctly when pushed with toany and GC'd by Lua
    func test_pushuserdata_instance() {
        var deinited = 0
        class Foo {
            let deinitPtr: UnsafeMutablePointer<Int>
            init(deinitPtr: UnsafeMutablePointer<Int>) {
                self.deinitPtr = deinitPtr
            }
            deinit {
                deinitPtr.pointee = deinitPtr.pointee + 1
            }
        }
        var val: Foo? = Foo(deinitPtr: &deinited)
        XCTAssertEqual(deinited, 0)

        L = LuaState(libraries: [])
        L.registerMetatable(for: Foo.self, functions: [:])
        L.pushuserdata(val!)
        L.pushany(val!)
        var userdataFromPushUserdata: Foo? = L.touserdata(1)
        var userdataFromPushAny: Foo? = L.touserdata(2)
        XCTAssertIdentical(userdataFromPushUserdata, userdataFromPushAny)
        XCTAssertIdentical(userdataFromPushUserdata, val)
        L.pop() // We only need one ref Lua-side
        userdataFromPushAny = nil
        userdataFromPushUserdata = nil
        val = nil
        // Should not have destructed at this point, as reference still held by Lua
        L.collectgarbage()
        XCTAssertEqual(deinited, 0)
        L.pop()
        L.collectgarbage() // val should now destruct
        XCTAssertEqual(deinited, 1)
    }

    func test_registerMetatable() throws {
        L = LuaState(libraries: [])
        class SomeClass {
            var member: String? = nil
        }
        L.registerMetatable(for: SomeClass.self, functions: [
            "__call": { (L: LuaState!) -> CInt in
                guard let obj: SomeClass = L.touserdata(1) else {
                    fatalError("Shouldn't happen")
                }
                obj.member = L.tostring(2)
                return 0
            }
        ])
        let val = SomeClass()
        L.pushuserdata(val)
        try L.pcall(arguments: "A string arg")
        XCTAssertEqual(val.member, "A string arg")
    }

    func testClasses() throws {
        // "outer Foo"
        class Foo {
            var str: String?
        }
        let f = Foo()
        L = LuaState(libraries: [])
        L.registerMetatable(for: Foo.self, functions: ["__call": { (L: LuaState!) -> CInt in
            let f: Foo? = L.touserdata(1)
            // Above would have failed if we get called with an innerfoo
            XCTAssertNotNil(f)
            f!.str = L.tostring(2)
            return 0
        }])
        L.pushuserdata(f)

        if true {
            // A different Foo ("inner Foo")
            class Foo {
                var str: String?
            }
            L.registerMetatable(for: Foo.self, functions: ["__call": { (L: LuaState!) -> CInt in
                let f: Foo? = L.touserdata(1)
                // Above would have failed if we get called with an outerfoo
                XCTAssertNotNil(f)
                f!.str = L.tostring(2)
                return 0
            }])
            let g = Foo()
            L.pushuserdata(g)

            try L.pcall(arguments: "innerfoo") // pops g
            try L.pcall(arguments: "outerfoo") // pops f

            XCTAssertEqual(g.str, "innerfoo")
            XCTAssertEqual(f.str, "outerfoo")
        }
    }

    func test_pushany() {
        L = LuaState(libraries: [])

        L.pushany(1234)
        XCTAssertEqual(L.toany(1) as? Int, 1234)
        L.pop()

        L.pushany("string")
        XCTAssertNil(L.toany(1, guessType: false) as? String)
        XCTAssertNotNil(L.toany(1, guessType: true) as? String)
        XCTAssertNotNil(L.toany(1, guessType: false) as? LuaStringRef)
        L.pop()

        // This is directly pushable (because Int is)
        let intArray = [11, 22, 33]
        L.pushany(intArray)
        XCTAssertEqual(L.type(1), .table)
        L.pop()

        struct Foo {
            let val: String
        }
        L.registerMetatable(for: Foo.self, functions: [:])
        let fooArray = [Foo(val: "a"), Foo(val: "b")]
        L.pushany(fooArray)
        XCTAssertEqual(L.type(1), .table)
        let guessAnyArray = L.toany(1, guessType: true) as? Array<Any>
        XCTAssertNotNil(guessAnyArray)
        XCTAssertEqual((guessAnyArray?[0] as? Foo)?.val, "a")
        let typedArray = guessAnyArray as? Array<Foo>
        XCTAssertNotNil(typedArray)

        let arr: [Foo]? = L.tovalue(1)
        XCTAssertNotNil(arr)
        L.pop()
    }

    func test_pushany_table() {
        L = LuaState(libraries: [])

        let stringArray = ["abc", "def"]
        L.pushany(stringArray)
        let stringArrayResult: [String]? = L.tovalue(1)
        XCTAssertEqual(stringArrayResult, stringArray)
        L.pop()

        let stringArrayArray = [["abc", "def"], ["123"]]
        L.pushany(stringArrayArray)
        let stringArrayArrayResult: [[String]]? = L.tovalue(1)
        XCTAssertEqual(stringArrayArrayResult, stringArrayArray)
        L.pop()

        let intBoolDict = [ 1: true, 2: false, 3: true ]
        L.pushany(intBoolDict)
        let intBoolDictResult: [Int: Bool]? = L.tovalue(1)
        XCTAssertEqual(intBoolDictResult, intBoolDict)
        L.pop()

        let stringDict = ["abc": "ABC", "def": "DEF"]
        L.pushany(stringDict)
        let stringDictResult: [String: String]? = L.tovalue(1)
        XCTAssertEqual(stringDictResult, stringDict)
        L.pop()

        let arrayDictDict = [["abc": [1: "1", 2: "2"], "def": [5: "5", 6: "6"]]]
        L.pushany(arrayDictDict)
        let arrayDictDictResult: [[String : [Int : String]]]? = L.tovalue(1)
        XCTAssertEqual(arrayDictDictResult, arrayDictDict)
        L.pop()
    }

    func testNonHashableTableKeys() {
        L = LuaState(libraries: [])
        struct NonHashable {
            let nope = true
        }
        L.registerMetatable(for: NonHashable.self, functions: [:])
        lua_newtable(L)
        L.pushuserdata(NonHashable())
        L.push(true)
        lua_settable(L, -3)
        let tbl = L.toany(1, guessType: true) as? [LuaNonHashable: Bool]
        XCTAssertNotNil(tbl)
    }

    func testAnyHashable() {
        // Just to make sure casting to AnyHashable behaves as expected
        let x: Any = 1
        XCTAssertNotNil(x as? AnyHashable)
        struct NonHashable {}
        let y: Any = NonHashable()
        XCTAssertNil(y as? AnyHashable)
    }
}
