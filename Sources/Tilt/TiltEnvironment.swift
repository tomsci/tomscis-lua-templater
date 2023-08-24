// Copyright (c) 2023 Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Lua

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
        L = LuaState(libraries: .all)
        // Obviously this no longer works as we don't have a bundle anymore.
//        L.setRequireRoot(Bundle.module.url(forResource: "src", withExtension: nil)!.path, displayPrefix: "Tilt/")
        L.getglobal("require")
        try! L.pcall("templater")
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
