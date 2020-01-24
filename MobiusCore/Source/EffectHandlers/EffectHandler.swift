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

/// This protocol defines the contract for an Effect Handler which takes `Effect`s as input, and produces `Event`s as output.
/// For each incoming `Effect`, zero or more `Event`s can be sent as output using `callback.send(Event)`.
/// When an `Effect` has been completely handled, i.e. that effect will not result in any more events, call `callback.end()`.
///
/// Note: `EffectHandler` should be used in conjunction with an `EffectRouter`.
public protocol EffectHandler {
    associatedtype Effect
    associatedtype Event

    /// Handle an `Effect`.
    /// To output events, call `callback.send`.
    /// When you are done handling `input`, be sure to call `callback.end()` to prevent memory leaks.
    /// If it does not make sense to finish handling an effect, you should be using a `Connectable` instead of this protocol.
    ///
    /// Note: When being disposed by Mobius, the `Disposable` you return will be called before Mobius calls `callback.end()`.
    /// Note: Mobius will not dispose the returned `Disposable` if `callback.end()` has already been called.
    ///
    /// Return a `Disposable` which tears down any resources that is being used by this effect handler.
    func handle(
        _ input: Effect,
        _ callback: EffectCallback<Event>
    ) -> Disposable
}

/// A type-erased wrapper of the `EffectHandler` protocol.
public struct AnyEffectHandler<Effect, Event>: EffectHandler {
    private let handler: (Effect, EffectCallback<Event>) -> Disposable

    /// Creates an anonymous `EffectHandler` that implements `handle` with the provided closure.
    ///
    /// - Parameter handle: An effect handler `handle` function; see the documentation for `EffectHandler.handle`.
    public init(handle: @escaping (Effect, EffectCallback<Event>) -> Disposable) {
        self.handler = handle
    }

    /// Creates a type-erased `EffectHandler` that wraps the given instance.
    public init<Handler: EffectHandler>(
        handler: Handler
    ) where Handler.Effect == Effect, Handler.Event == Event {
        self.init(handle: handler.handle)
    }

    public func handle(_ input: Effect, _ callback: EffectCallback<Event>) -> Disposable {
        return self.handler(input, callback)
    }
}
