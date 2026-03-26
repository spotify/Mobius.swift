// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The `EmptyDisposable` class implements a `Disposable` type for when you don't have anything to dispose of.
public final class EmptyDisposable: MobiusCore.Disposable {

    /// Create an `EmptyDisposable`
    public init() {}

    public func dispose() {
        // No-op
    }
}
