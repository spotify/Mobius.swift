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

/// This protocol defines the contract for an Effect Handler which takes `EffectParameters` as input, and produces
/// `Event`s as output.
///
/// For each input to the `handle` function, zero or more `Event`s can be sent as output using `callback.send(Event)`.
/// Once the effect has been completely handled (i.e. when the handler will not produce any more events)
/// call `callback.end()`.
///
/// Note: `EffectHandler` should be used in conjunction with an `EffectRouter`.
public protocol EffectHandler {
    associatedtype EffectParameters
    associatedtype Event

    /// Handle an effect with `EffectParameters` as its associated values.
    ///
    /// To output events, call `callback.send`.
    /// Call `callback.end()` once the input has been handled to prevent memory leaks.
    ///
    /// This returns a `Disposable` which cancels the handling of this effect. This `Disposable` will
    /// not be called if `callback.end()` has already been called.
    ///
    /// Note: If it does not make sense to finish handling an effect, you should be using a `Connectable` instead of
    /// this protocol.
    /// Note: Mobius will not dispose the returned `Disposable` if `callback.end()` has already been called.
    /// - Parameter effectParameters: The associated values of the loop `Effect` being handled.
    /// - Parameter callback: The `EffectCallback` used to communicate with the associated Mobius loop.
    func handle(
        _ effectParameters: EffectParameters,
        _ callback: EffectCallback<Event>
    ) -> Disposable
}

/// A type-erased wrapper of the `EffectHandler` protocol.
public struct AnyEffectHandler<EffectParameters, Event>: EffectHandler {
    private let handleClosure: (EffectParameters, EffectCallback<Event>) -> Disposable

    /// Creates an anonymous `EffectHandler` that implements `handle` with the provided closure.
    ///
    /// - Parameter handle: An effect handler `handle` function; see the documentation for `EffectHandler.handle`.
    public init(handle: @escaping (EffectParameters, EffectCallback<Event>) -> Disposable) {
        self.handleClosure = handle
    }

    /// Creates a type-erased `EffectHandler` that wraps the given instance.
    public init<Handler: EffectHandler>(
        handler: Handler
    ) where Handler.EffectParameters == EffectParameters, Handler.Event == Event {
        let handleClosure: (EffectParameters, EffectCallback<Event>) -> Disposable

        if let anyHandler = handler as? AnyEffectHandler {
            handleClosure = anyHandler.handleClosure
        } else {
            handleClosure = handler.handle
        }

        self.init(handle: handleClosure)
    }

    public func handle(_ parameters: EffectParameters, _ callback: EffectCallback<Event>) -> Disposable {
        return self.handleClosure(parameters, callback)
    }
}
