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

/// Superclass that allows for easy implementation of a Mobius loop `EventSource`
///
/// This class automatically handles locking for thread safety. To allow subclasses to subscribe to external sources,
/// within a thread safe environment, you need to override the following methods.
///
/// `onSubscribe`: this function is called within a lock, here its safe to add observers such as NSNotification
/// observers.
///
/// `onDispose`: this function is called when the loop has disposed the `EventSource`. Any resources or observations
/// used by the subclass should be freed here. When this function is called, the base class has already
/// released all its resources so no further functions should be run on the base class.
///
/// - Attention: Should not be used directly. Instead a subclass should be used which overrides the
/// `onSubscribe` and `onDispose` methods.
open class EventSourceClass<Event>: NSObject, EventSource {

    private let lock = NSRecursiveLock()
    private var consumer: Consumer<Event>?
    var handleError = { (message: String) -> Void in
        fatalError(message)
    }

    /// Called when the `EventSource` is subscribed, this is where you can add you external observers.
    ///
    /// - Attention: This function has to be overridden by a subclass or an error will be thrown to the MobiusHooks
    /// error handler.
    open func onSubscribe() {
        handleError("The function `\(#function)` must be overridden in subclass \(type(of: self))")
    }

    /// Called when the `EventSource` is disposed, this is where you should remove any external observers you have.
    ///
    /// - Attention: This function has to be overridden by a subclass or an error will be thrown to the MobiusHooks
    /// error handler.
    open func onDispose() {
        handleError("The function `\(#function)` must be overridden in subclass \(type(of: self))")
    }

    public final func subscribe(consumer: @escaping Consumer<Event> ) -> Disposable {
        lock.lock()
        defer { lock.unlock() }
        self.consumer = consumer
        onSubscribe()
        return AnonymousDisposable(disposer: dispose)
    }

    /// Allows the subclass to pass `T.Event` back to the loop.
    ///
    /// - Attention: This class will throw an error to the MobiusHooks error handler if a connection has not been
    /// established before a call to this function is made. Setting up a connection is usually handled by the MobiusLoop
    public final func send(_ event: Event) {
        lock.lock()
        defer { lock.unlock() }
        guard let consumer = consumer else {
            handleError("\(type(of: self)) is unable to send \(type(of: event)) before any consumer has been set. Send should only be used once the EventSource has been properly connected.")
            return
        }
        consumer(event)
    }

    public final func dispose() {
        lock.lock()
        defer { lock.unlock() }
        consumer = nil
        onDispose()
    }
}
