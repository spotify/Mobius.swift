// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Types adopting the `Copyable` protocol can be copied and changed in one operation.
public protocol Copyable {
    /// Copy the `Copyable` object and change one or more of its members.
    ///
    /// - Note: A default implementation is provided that can be used with value types. If the type adopting the
    ///         `Copyable` protocol is a reference type then it needs to provide its own implementation.
    ///
    /// - Parameter mutator: The closure that changes the copy.
    /// - Returns: The changed copy.
    func copy(with mutator: (inout Self) -> Void) -> Self
}

public extension Copyable {
    func copy(with mutator: (inout Self) -> Void) -> Self {
        var copy = self
        mutator(&copy)
        return copy
    }
}
