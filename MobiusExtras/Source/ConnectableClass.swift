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
import MobiusCore

/// Superclass that allows for easy implementation of a Mobius loop `Connectable`
///
/// - Attention: Should not be used directly. Instead a subclass should be used which overrides any of combination of
/// the `handle`, `onConnect`, and `onDispose` functions.
///
/// This class automatically handles creation of `Connection`. Any subclass can override any of the following functions:
///   - `handle`: this function handles any input (i.e. T.Effects). If a `T.Event` is should be sent to the loop,
///      it should be passed to the `send` function which will pass it to the Mobius loop
///
///   - `onConnect`: this function is called when the connection is being established. It can be used to allocate and
///     initialize any resources used by the subclass.
///
///   - `onDispose`: this function is called when the loop has disposed of the `Connectable`. Any resources used by the
///     subclass should be freed here. When this function is called, the base class has already released all its
///     resources so no further functions should be run on the base class.
open class ConnectableClass<Input, Output>: Connectable {
    private var consumer: Consumer<Output>?

    private let lock = NSRecursiveLock()

    public init() {}

    /// Allows the subclass to pass data back through the established `Connection`. In the case of a Mobius loop effect
    /// handler, this is the function to call to pass `T.Event` back to the loop
    ///
    /// - Attention: This class will throw an error to the MobiusHooks error handler if a connection has not been
    /// established before a call to this function is made. Setting up a connection is usually handled by the MobiusLoop
    public final func send(_ output: Output) {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard let consumer = consumer else {
            return
        }

        consumer(output)
    }

    /// Called when the `Connectable` receives input to allow the subclass to react to it.
    open func handle(_ input: Input) {}

    /// Called when the connection is being established. This function can be used to allocate and initialize any
    /// resources used by the subclass.
    open func onConnect() {}

    /// Called when the connection is being disposed. This function should release any resources used by the subclass.
    open func onDispose() {}

    public final func connect(_ consumer: @escaping (Output) -> Void) -> Connection<Input> {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard self.consumer == nil else {
            MobiusHooks.errorHandler(
                "Connection limit exceeded: The Connectable \(type(of: self)) is already connected. " +
                "Unable to connect more than once",
                #file,
                #line
            )
        }

        self.consumer = consumer
        onConnect()
        return Connection(acceptClosure: self.accept, disposeClosure: self.dispose)
    }

    private func accept(_ input: Input) {
        // The construct of consumerSet is there to release the lock asap.
        // We don’t know what goes on in the overridden `handle` function...
        var consumerSet: Bool = false
        lock.lock()
        consumerSet = consumer != nil
        lock.unlock()
        guard consumerSet else {
            MobiusHooks.errorHandler(
                "\(type(of: self)) is unable to handle \(type(of: input)) before any consumer has been set",
                #file,
                #line
            )
        }

        handle(input)
    }

    private func dispose() {
        lock.lock()
        consumer = nil
        lock.unlock()
        onDispose()
    }
}
