// Copyright (c) 2020 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation

/// The `AnonymousDisposable` class implements a `Disposable` type that disposes of resources via a closure.
public final class AnonymousDisposable: MobiusCore.Disposable {
    /// The closure which disposes of the object.
    private var disposer: (() -> Void)?
    private let lock = DispatchQueue(label: "Mobius.AnonymousDisposable")

    /// Creates a type-erased `AnonymousDisposable` that wraps the given instance.
    public convenience init<Disposable: MobiusCore.Disposable>(_ base: Disposable) {
        // Note: This doesn’t use the thunk-avoiding pattern of the `Any...` wrappers, because it would break the
        // single-disposal guarantee that `AnonymousDisposable` adds. This could be handled by making the contents of
        // `dispose` a closure we set up in `init(disposer:)`, but that doesn’t seem motivated without evidence that
        // recursive wrapping of `AnonymousDisposable` is a common thing.
        self.init(disposer: base.dispose)
    }

    /// Create an `AnonymousDisposable` that will run the provided closure when disposed.
    ///
    /// - Warning: The given `disposer` closure **will be discarded** as soon as the resources have been disposed.
    ///
    /// - Parameter disposer: The code which disposes of the resources.
    public init(disposer: @escaping () -> Void) {
        self.disposer = disposer
    }

    public func dispose() {
        var disposer: (() -> Void)?

        lock.sync {
            disposer = self.disposer
            self.disposer = nil
        }

        disposer?()
    }
}
