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

/// An `EffectHandler` is a building block in Mobius loops which carry out side-effects in response to effects emitted by the `update` function.
/// `EffectHandler`s compose with themselves; simply supply the initializer with an array of `EffectHandler`s.
///
/// Note: Each effect emitted in a Mobius loop must be handled by exactly __one__ `EffectHandler`.  When composing `EffectHandler`s, at most one
/// `EffectHandler` can handle a given effect.
/// Note: The `connnect` function is invoked on an `EffectHandler` when it should start handling effects and emitting events. Only one `Connection` at
/// a time is supported, otherwise it will crash.
/// Note: It is possible to emit events before `connect` has been called on an `EffectHandler`, and after a `Connection` to an `EffectHandler` has
/// been disposed. These events can not, and will not be handled by anything. This will therefore cause a crash.
/// Note: Any resources used by an `EffectHandler` must be disposed when a connection to the `EffectHandler` is disposed. The `stopHandling`
/// parameter is used to specify which resources should be torn down when this happens.
final public class EffectHandler<Effect, Event> {
    private let lock = Lock()
    let handleEffect: (Effect) -> ((@escaping Consumer<Event>) -> Void)?
    private let disposeFn: () -> Void
    private var consumer: Consumer<Event>?

    /// Create a handler for effects which satisfy the `canHandle` parameter function.
    ///
    /// - Parameter canHandle: A function which determines if this EffectHandler can handle a given effect. If it can handle the effect, return the data
    /// that should be sent as input to the `handle` function. If it cannot handle the effect, return `nil`
    /// - Parameter handleEffect: Handle effects which satisfy `canHandle`.
    /// - Parameter stopHandling: Tear down any resources being used by this effect handler.
    public convenience init<EffectPayload>(
        canHandle: @escaping (Effect) -> EffectPayload?,
        handle: @escaping (EffectPayload, @escaping Consumer<Event>) -> Void,
        stopHandling disposable: @escaping () -> Void = {}
    ) {
        self.init(
            handleEffect: { effect in
               if let payload = canHandle(effect) {
                   return { dispatch in
                       handle(payload, dispatch)
                   }
               } else {
                   return nil
               }
            },
            stopHandling: disposable
        )
    }

    init(
        handleEffect: @escaping (Effect) -> ((@escaping Consumer<Event>) -> Void)?,
        stopHandling disposable: @escaping () -> Void
    ) {
        disposeFn = disposable
        self.handleEffect = handleEffect
    }

    /// Connect to this `EffectHandler` by supplying it with an output for its events.
    /// This will return a `Connection` which you can use to send effects to this `EffectHandler` and to tear down the connection.
    ///
    /// NOTE: Only one connection can be held to this `EffectHandler` at a time.
    ///
    /// - Parameter consumer: the output that this `EffectHandler` should send its events to.
    public func connect(_ consumer: @escaping (Event) -> Void) -> Connection<Effect> {
        return lock.synchronized {
            guard self.consumer == nil else {
                MobiusHooks.onError("An EffectHandler only supports one connection at a time.")
                return BrokenConnection<Effect>.connection()
            }
            self.consumer = consumer

            return Connection(
                acceptClosure: self.accept,
                disposeClosure: self.dispose
            )
        }
    }

    func canAccept(_ effect: Effect) -> Bool {
        return handleEffect(effect) != nil
    }

    private func accept(_ effect: Effect) {
        if let performEffect = handleEffect(effect) {
            performEffect { [unowned self] event in
                self.dispatch(event: event)
            }
        }
    }

    private func dispatch(event: Event) {
        return lock.synchronized {
            guard let consumer = self.consumer else {
                MobiusHooks.onError("Nothing is connected to this `EffectHandler`. Ensure your resources have been cleaned up in `stopHandling`")
                return
            }

            consumer(event)
        }
    }

    func dispose() {
        lock.synchronized {
            disposeFn()

            consumer = nil
        }
    }
}

public extension EffectHandler where Effect: Equatable {
    /// Create a handler for effects which are equal to the `acceptsEffect` parameter.
    ///
    /// - Parameter handledEffect: a constant effect which should be handled by this effect handler.
    /// - Parameter handle: handle effects which are equal to the `handledEffect`.
    /// - Parameter stopHandling: Tear down any resources being used by this effect handler
    convenience init(
        handledEffect acceptedEffect: Effect,
        handle: @escaping (Effect, @escaping Consumer<Event>) -> Void,
        stopHandling: @escaping () -> Void = {}
    ) {
        self.init(
            canHandle: { effect in
                effect == acceptedEffect
                    ? effect
                    : nil
            },
            handle: handle,
            stopHandling: stopHandling
        )
    }
}
