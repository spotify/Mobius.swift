// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

/// Types adopting the `Disposable` protocol can be disposed, cleaning up the resources referenced.
///
/// The resources can be anything; ranging from a network request, task on the CPU or an observation of another resource.
///
/// See also `AnonymousDisposable` for a concrete anonymous implementation.
public protocol Disposable: AnyObject {
    /// Dispose of all resources associated with the `Disposable` object.
    ///
    /// The `Disposable` will no longer be valid after `dispose` has been called, and any further calls to `dispose`
    /// should not have any effect.
    func dispose()
}
