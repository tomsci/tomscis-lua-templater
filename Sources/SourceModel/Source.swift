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

import Foundation

public enum SourceModelError: Error {
    case corrupt
}

public struct Source: Codable {

    public let files: [String: Data]

    public init(files: [String: Data]) {
        self.files = files
    }

    public init(base64EncodedString: String) throws {
        guard let data = Data(base64Encoded: base64EncodedString) else {
            throw SourceModelError.corrupt
        }
        let decoder = JSONDecoder()
        self = try decoder.decode(Source.self, from: data)
    }

    public func base64EncodedString() throws -> String {
        return try JSONEncoder().encode(self).base64EncodedString()
    }

}
