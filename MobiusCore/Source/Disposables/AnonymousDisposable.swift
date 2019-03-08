// Copyright (c) 2019 Spotify AB.
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
public class AnonymousDisposable: MobiusCore.Disposable {
    /// The closure which disposes of the object.
    private var disposer: (() -> Void)?
    private let lock = NSRecursiveLock()

    /// Initialize the `DisposableClosure` with the given code to run on disposing the resources.
    ///
    /// - Warning: The given _disposer_ **closure will be discarded** as soon as the resources have been disposed.
    ///
    /// - Parameter disposer: The code which disposes of the resources.
    public init(disposer: @escaping () -> Void) {
        self.disposer = disposer
    }

    public func dispose() {
        lock.synchronized {
            guard let disposer = disposer else { return }

            disposer()
            self.disposer = nil
        }
    }
}
