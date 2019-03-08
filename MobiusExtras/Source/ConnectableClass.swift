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
import MobiusCore

/// Superclass that allows for easy implementation of a Mobius loop `Connectable` as described above
///
/// This class automatically handles creation of `Connection`. Any subclass should override the following functions
///
/// `handle`: this function handles any input (i.e. T.Effects). If a `T.Event` is should be sent to the loop,
/// it should be passed to the `send` function which will pass it to the Mobius loop
///
/// `disposed`: this function is called when the loop has disposed of the `Connectable`. Any resources used by the
/// subclass should be freed here. When this function is called, the base class has already released all its resources
/// so no further functions should be run on the base class.
///
/// - Attention: Should not be used directly. Instead a subclass should be used which overrides the
/// `handle` and `disposed` functions
open class ConnectableClass<InputType, OutputType>: Connectable {
    private var consumer: Consumer<OutputType>?

    private let lock = NSRecursiveLock()
    var handleError = { (message: String) -> Void in
        fatalError(message)
    }

    public init() {}

    /// Allows the subclass to pass data back through the established `Connection`. In the case of a Mobius loop effect
    /// handler, this is the function to call to pass `T.Event` back to the loop
    ///
    /// - Attention: This class will throw an error to the MobiusHooks error handler if a connection has not been
    /// established before a call to this function is made. Setting up a connection is usually handled by the MobiusLoop
    public final func send(_ output: OutputType) {
        lock.synchronized {
            guard let consumer = consumer else {
                handleError("\(type(of: self)) is unable to send \(type(of: output)) before any consumer has been set. Send should only be used once the Connectable has been properly connected.")
                return
            }

            consumer(output)
        }
    }

    /// Called when the `Connectable` receives input to allow the subclass to react to it.
    ///
    /// - Attention: This function has to be overridden by a subclass or an error will be thrown to the MobiusHooks
    /// error handler.
    open func handle(_ input: InputType) {
        handleError("The function `\(#function)` must be overridden in subclass \(type(of: self))")
    }

    /// Called when its being disposed. This function should release any resources used by the subclass.
    ///
    /// - Attention: This function has to be overridden by a subclass or an error will be thrown to the MobiusHooks
    /// error handler.
    open func onDispose() {
        handleError("The function `\(#function)` must be overridden in subclass \(type(of: self))")
    }

    public final func connect(_ consumer: @escaping (OutputType) -> Void) -> Connection<InputType> {
        return lock.synchronized { () -> Connection<InputType> in
            guard self.consumer == nil else {
                handleError("ConnectionLimitExceeded: The Connectable \(type(of: self)) is already connected. Unable to connect more than once")
                return BrokenConnection<InputType>.connection()
            }

            self.consumer = consumer
            return Connection<InputType>(acceptClosure: self.accept, disposeClosure: self.dispose)
        }
    }

    private func accept(_ input: InputType) {
        // The construct of consumerSet is there to release the lock asap.
        // We dont know what goes on in the overriden `handle` function...
        var consumerSet: Bool = false
        lock.synchronized {
            consumerSet = consumer != nil
        }
        guard consumerSet else {
            handleError("\(type(of: self)) is unable to handle \(type(of: input)) before any consumer has been set")
            return
        }

        handle(input)
    }

    private func dispose() {
        lock.synchronized {
            consumer = nil
        }
        onDispose()
    }
}
