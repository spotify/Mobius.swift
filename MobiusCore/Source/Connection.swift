// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Handle for a connection created by a `Connectable`.
///
/// Used for sending values to the connection and to dispose of it and all resources associated with it.
public final class Connection<Value>: Disposable {
    private let acceptClosure: (Value) -> Void
    private let disposeClosure: () -> Void

    /// Create a new connection that calls `acceptClosure` for incoming values, and `disposeClosure` when disposed.
    public init(acceptClosure: @escaping (Value) -> Void, disposeClosure: @escaping () -> Void) {
        self.acceptClosure = acceptClosure
        self.disposeClosure = disposeClosure
    }

    /// Send a value to the connection.
    public func accept(_ value: Value) {
        acceptClosure(value)
    }

    public func dispose() {
        disposeClosure()
    }
}
