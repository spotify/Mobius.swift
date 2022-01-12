// Copyright 2019-2022 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Adds a hook-in point for handling fatal errors when using Mobius. Fatal errors are programmer mistakes; incorrect
/// usage of Mobius APIs.
///
/// The default behaviour is to crash the application through invoking the `defaultErrorHandler` function defined in
/// this enum. If that is not the desired behaviour, you can override it through the `setErrorHandler` method.
public enum MobiusHooks {
    public typealias ErrorHandler = (String, StaticString, UInt) -> Never

    /// Internal: we prefer to call `errorHandler` directly, without abstractions, to minimize the depth of crash
    /// stack traces. This requires that `#file` and `#line` are passed explicitly.
    public private(set) static var errorHandler: ErrorHandler = MobiusHooks.defaultErrorHandler

    public static func setErrorHandler(_ newErrorHandler: @escaping ErrorHandler) {
        errorHandler = newErrorHandler
    }

    public static func setDefaultErrorHandler() {
        errorHandler = defaultErrorHandler
    }

    public static func defaultErrorHandler(_ message: String = "", file: StaticString, line: UInt) -> Never {
        fatalError(message, file: file, line: line)
    }
}
