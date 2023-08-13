//
//  TiltEnvironment.swift
//  
//
//  Created by Tom Sutcliffe on 27/07/2023.
//

import Foundation

/// The Swift interface to Tilt.
///
/// After constructing a `TiltEnvironment` object, there are several configurations that can be made by directly
/// manipulating the Lua environment `L`.
///
/// Set a global function `readFile(path)` to customise where template includes are loaded from.
///
/// Set a global function `printWarning(text)` to customise where the output of `warning(...)` goes.
///
/// Call the global function `setContext(dict)` to add `dict` to the environment used by templates.
public class TiltEnvironment {
    public let L: LuaState

    public init() {
        L = LuaState(libraries: .all, encoding: .stringEncoding(.utf8))
        L.setRequireRoot(Bundle.module.url(forResource: "src", withExtension: nil)!.path, displayPrefix: "Tilt/")
        L.getglobal("require")
        try! L.pcall(arguments: "templater")
    }

    deinit {
        L.close()
    }

    public struct RenderResult {
        public let text: String
        public let includes: [String]
    }

    /// Render a template.
    ///
    /// - Parameter filename: The name to associate with the template. Used only for logging.
    /// - Parameter contents: The text of the template to render.
    /// - Parameter globalIncludes: Optionally, specify one or more files to include prior to rendering the template.
    ///   These are treated as if `contents` started with `include "<path>"` for each path in `globalIncludes`.
    /// - Throws: `LuaCallError` if a Lua error is raised during the render.
    /// - Returns: A `Render` result containing the text result and all the templates used by the render (which will
    ///   always include `filename` and anything in `globalIncludes`).
    public func render(filename: String, contents: String, globalIncludes: [String] = []) throws -> RenderResult {
        L.settop(0)
        L.getglobal("render")
        L.push(filename)
        L.push(contents)
        L.push(globalIncludes)
        // render() does its own xpcall around doRender() so don't add another traceback on here.
        try L.pcall(nargs: 3, nret: 2, traceback: false)
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
