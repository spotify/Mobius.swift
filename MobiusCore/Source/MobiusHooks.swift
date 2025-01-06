// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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
