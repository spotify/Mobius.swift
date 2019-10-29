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

public enum HandleEffect<Type> {
    case handle(Type)
    case ignore
}

/// An `EffectHandler` is a building block in Mobius loops which carry out side-effects in response to effects emitted by the `update` function.
/// An `EffectHandler` decides which effects it can handle based on its `canAccept` function. Multiple `EffectHandler`s can be composed by using an
/// `EffectRouterBuilder`.
///
/// Note: When using an `EffectRouterBuilder` each effect must be handled by exactly one `EffectHandler`.
/// Note: The `connnect` function is invoked on an `EffectHandler` when it should start handling effects and emitting events. Only one `Connection` at
/// a time is supported, otherwise it will crash.
/// Note: It is possible to emit events before `connect` has been called on an `EffectHandler`, and after a `Connection` to an `EffectHandler` has
/// been disposed. These events can not, and will not be handled by anything. This will therefore cause a crash.
/// Note: Any resources used by an `EffectHandler` must be disposed when a connection to the `EffectHandler` is disposed. The `onDispose`
/// parameter is used to specify which resources should be torn down when this happens.
final public class EffectHandler<Effect, Event> {
    private let lock = Lock()
    private let handleEffect: (Effect) -> ((@escaping Consumer<Event>) -> Void)?
    private let disposeFn: () -> Void
    private var consumer: Consumer<Event>?

    /// Create a handler for effects which satisfy the `canAccept` parameter function.
    ///
    /// - Parameter canHandle: A function which indicates whether to handle an effect. If it returns `.handle(effect)` for a given `effect`, this
    /// effect handler will handle said effect.
    /// - Parameter handleEffect: Handle effects which satisfy `canAccept`.
    /// - Parameter onDispose: Tear down any resources being used by this effect handler.
    public init<AssociatedValueType>(
        canHandle: @escaping (Effect) -> HandleEffect<AssociatedValueType>,
        handleEffect: @escaping (AssociatedValueType, @escaping Consumer<Event>) -> Void,
        onDispose disposable: @escaping () -> Void
    ) {
        disposeFn = disposable
        self.handleEffect = { effect in
            switch canHandle(effect) {
            case .handle(let subEffect):
                return { dispatch in
                    handleEffect(subEffect, dispatch)
                }
            case .ignore: return nil
            }
        }
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
                fatalError("An EffectHandler only supports one connection at a time.")
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
                fatalError("Nothing is connected to this `EffectHandler`. Ensure your resources have been cleaned up in `onDispose`")
            }

            consumer(event)
        }
    }

    private func dispose() {
        lock.synchronized {
            disposeFn()

            consumer = nil
        }
    }
}

public extension EffectHandler where Effect: Equatable {
    /// Create a handler for effects which are equal to the `acceptsEffect` parameter.
    ///
    /// - Parameter acceptedEffect: a constant effect which should be handled by this effect handler.
    /// - Parameter handleEffect: handle effects which are equal to `acceptedEffect`.
    /// - Parameter onDispose: Tear down any resources being used by this effect handler
    convenience init(
        acceptsEffect acceptedEffect: Effect,
        handleEffect: @escaping (Effect, @escaping Consumer<Event>) -> Void,
        onDispose: @escaping () -> Void = {}
    ) {
        self.init(
            canHandle: { effect in
                if effect == acceptedEffect {
                    return .handle(effect)
                } else {
                    return .ignore
                }
            },
            handleEffect: handleEffect,
            onDispose: onDispose
        )
    }
}
