// Copyright (c) 2023 Tom Sutcliffe, Jason Morley
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

import ArgumentParser
import Foundation

import SourceModel

@main
struct Command: ParsableCommand {
    
    @Argument
    var sources: [String]

    @Option
    var sourceRoot: String

    @Option
    var output: String

    func run() throws {

        // Convert the sources to relative URLs so that, should we need to, we can reference their full relative path
        // in the source tree. Ideally we'd pull these relative paths out in the Package Manager Plugin, but it doesn't
        // seem to provide any way to do it, so we're doing it here instead.
        let sourceRoot = sourceRoot.ensuringSuffix("/")
        let sourceRootURL = URL(filePath: sourceRoot, directoryHint: .isDirectory)
        let sourceURLs = try sources.map { source in
            guard source.hasPrefix(sourceRoot) else {
                throw EmbedLuaError.general("Source '\(source)' is not within source root '\(sourceRoot)'.")
            }
            let relativePath = String(source.dropFirst(sourceRoot.count))
            return URL(filePath: relativePath, relativeTo: sourceRootURL)
        }

        let outputURL = URL(filePath: output)
        let files = try sourceURLs
            .reduce(into: [String: Data]()) { partialResult, sourceURL in
                partialResult[sourceURL.relativePath] = try Data(contentsOf: sourceURL)
            }
        let source = Source(files: files)
        let base64EncodedString = try source.base64EncodedString()

        let contents = """
import SourceModel

struct LuaSource {

    static let `default`: Source = {
        return try! Source(base64EncodedString: \"\(base64EncodedString)\")
    }()

}
"""
        let data = contents.data(using: .utf8)
        try data?.write(to: outputURL)
    }

}
