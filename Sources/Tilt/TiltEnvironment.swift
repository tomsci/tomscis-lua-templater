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

    public init() {
        L = LuaState(libraries: .all, encoding: .stringEncoding(.utf8))
        L.setRequireRoot(Bundle.module.url(forResource: "src", withExtension: nil)!.path, displayPrefix: "Tilt/")
        L.getglobal("require")
        try! L.pcall(arguments: "templater")
    }

    public struct RenderResult {
        public let text: String
        public let includes: [String]
    }

    public typealias ParseResult = RenderResult

    @available(*, deprecated, message: "`parse()` has been replaced by `render()`")
    public func parse(filename: String, contents: String) throws -> ParseResult {
        return try render(filename: filename, contents: contents)
    }

    public func render(filename: String, contents: String) throws -> RenderResult {
        L.settop(0)
        L.getglobal("render")
        L.push(filename)
        L.push(contents)
        // render() does its own xpcall around doRender() so don't add another traceback on here.
        try L.pcall(nargs: 2, nret: 2, traceback: false)
        let result = L.tostring(1)!
        var includes: [String] = []
        for (k, _) in L.pairs(2) {
            if let include = L.tostring(k) {
                includes.append(include)
            }
        }
        L.settop(0)
        return RenderResult(text: result, includes: includes)
    }
}
