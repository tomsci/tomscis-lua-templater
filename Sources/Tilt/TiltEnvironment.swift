//
//  TiltEnvironment.swift
//  
//
//  Created by Tom Sutcliffe on 27/07/2023.
//

import Foundation
import TiltC

public class TiltEnvironment {
    public let L: LuaState
    let srcPath = Bundle.module.url(forResource: "src", withExtension: nil)!

    public init() {
        L = LuaState(libraries: .all, encoding: .stringEncoding(.utf8))
        let packagePath = srcPath.path + "/?.lua"
        L.getglobal("package")
        L.setfield("path", packagePath)
        L.pop()
        L.getglobal("require")
        L.push("templater")
        lua_call(L, 1, 0)
    }

    public struct ParseResult {
        public let text: String
        public let includes: [String]
        public let warnings: [String]
    }

    public func parse(filename: String, contents: String) throws -> ParseResult {
        L.settop(0)
        L.getglobal("parse")
        L.push(filename)
        L.push(contents)
        try L.pcall(nargs: 2, nret: 3)
        let result = L.tostring(1)!
        let includes = L.tostringarray(2)!
        let warnings = L.tostringarray(3)!
        return ParseResult(text: result, includes: includes, warnings: warnings)
    }
}
