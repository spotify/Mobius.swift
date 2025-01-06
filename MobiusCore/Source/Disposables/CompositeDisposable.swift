// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A CompositeDisposable holds onto the provided disposables and disposes all of them once its `dispose` method is
/// called.
public final class CompositeDisposable {
    private var disposables: [Disposable]
    private let lock = DispatchQueue(label: "Mobius.CompositeDisposable")

    /// Initializes a `CompositeDisposable`.
    ///
    /// - Parameter disposables: an array of disposables.
    init(disposables: [Disposable]) {
        self.disposables = disposables
    }
}

extension CompositeDisposable: MobiusCore.Disposable {
    /// Dispose function disposes all of the internal disposables.
    public func dispose() {
        var disposables = [Disposable]()

        lock.sync {
            disposables = self.disposables
            self.disposables.removeAll()
        }

        for disposable in disposables {
            disposable.dispose()
        }
    }
}
