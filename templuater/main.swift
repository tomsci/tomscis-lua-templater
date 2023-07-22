//
//  main.swift
//  templuater
//
//  Created by Tom Sutcliffe on 22/07/2023.
//

import Foundation

let L = LuaState(libraries: .all, encoding: .stringEncoding(.utf8))
if CommandLine.arguments.count != 2 {
    fatalError("Syntax: templuater <path/to/templater.lua>")
}
let templaterPath = CommandLine.arguments[1]

let x = luaL_dofile(L, templaterPath)
if x != 0 {
    let err = L.tostring(1) ?? "nil"
    fatalError("ret = \(x) err=\(err)")
}
