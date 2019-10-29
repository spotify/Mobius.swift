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

final public class EffectHandler<Effect, Event> {
    public typealias InputType = Effect
    public typealias OutputType = Event

    private let lock = NSRecursiveLock()
    private let handleEffect: (Effect, @escaping Consumer<Event>) -> Void
    private let canAcceptEffect: (Effect) -> Bool
    private let disposeFn: () -> Void
    private var consumer: Consumer<Event>?

    init<AssociatedValueType>(
        canAccept: @escaping (Effect) -> HandleEffect<AssociatedValueType>,
        handleEffect: @escaping (AssociatedValueType, @escaping Consumer<Event>) -> Void,
        onDispose disposable: @escaping () -> Void
    ) {
        disposeFn = disposable
        canAcceptEffect = { effect in
            switch canAccept(effect) {
            case .handle: return true
            default: return false
            }
        }
        self.handleEffect = { effect, dispatch in
            switch canAccept(effect) {
            case .handle(let subType):
                handleEffect(subType, dispatch)
            default:
                fatalError("ActionEffectHandler's canAccept is implemented incorrectly. This should not be possible")
            }
        }
    }

    func canAccept(_ effect: Effect) -> Bool {
        return canAcceptEffect(effect)
    }

    public func connect(_ consumer: @escaping (Event) -> Void) -> Connection<Effect> {
        lock.lock()
        defer { lock.unlock() }
        self.consumer = consumer

        return Connection(
            acceptClosure: self.accept,
            disposeClosure: self.dispose
        )
    }

    private func accept(_ effect: Effect) {
        if canAccept(effect) {
            handleEffect(effect) { [unowned self] effect in
                self.consumer?(effect)
            }
        }
    }

    private func dispatch(event: Event) {
        lock.lock()
        defer { lock.unlock() }
        consumer?(event)
    }

    private func dispose() {
        // Make sure that the `Connection` produced in the `connect` function is never used again
        lock.lock()
        defer { lock.unlock() }
        disposeFn()

        consumer = nil
    }
}

// MARK: - Public API for creating Effect Handlers

public enum HandleEffect<Type> {
    case handle(Type)
    case ignore
}

public extension EffectHandler {
    /// Create a handler for effects which satisfy the `canAccept` parameter function.
    ///
    /// - Parameter canAccept: A function which indicates whether to handle an effect. If it returns `.handle(effect)` for a given `effect`, this
    /// effect handler will handle said effect.
    /// - Parameter handleEffect: Handle effects which satisfy `canAccept`.
    /// - Parameter onDispose: Tear down any resources being used by this effect handler.
    static func makeEffectHandler<AssociatedValue>(
        canAccept: @escaping (Effect) -> HandleEffect<AssociatedValue>,
        handleEffect: @escaping (AssociatedValue, @escaping Consumer<Event>) -> Void,
        onDispose: @escaping () -> Void = {}
    ) -> EffectHandler<Effect, Event> {
        return EffectHandler<Effect, Event>(
            canAccept: canAccept,
            handleEffect: handleEffect,
            onDispose: onDispose
        )
    }
}

public extension EffectHandler where Effect: Equatable {
    /// Create a handler for effects which are equal to the `acceptsEffect` parameter.
    ///
    /// - Parameter acceptedEffect: a constant effect which should be handled by this effect handler.
    /// - Parameter handleEffect: handle effects which are equal to `acceptedEffect`.
    /// - Parameter onDispose: Tear down any resources being used by this effect handler
    static func makeEffectHandler(
        acceptsEffect acceptedEffect: Effect,
        handleEffect: @escaping (Effect, @escaping Consumer<Event>) -> Void,
        onDispose: @escaping () -> Void = {}
    ) -> EffectHandler<Effect, Event> {
        return EffectHandler<Effect, Event>(
            canAccept: { effect in
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
