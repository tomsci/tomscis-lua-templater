// Copyright (c) 2023 Tom Sutcliffe
// See LICENSE file for license information.

import Foundation
import Lua
import CLua

let L = LuaState(libraries: .all)

if CommandLine.arguments.count != 2 {
    fatalError("Syntax: templuater <path/to/templater.lua>")
}
let templaterPath = CommandLine.arguments[1]

let x = luaL_dofile(L, templaterPath)
if x != 0 {
    let err = L.tostring(1) ?? "nil"
    fatalError("ret = \(x) err=\(err)")
}
