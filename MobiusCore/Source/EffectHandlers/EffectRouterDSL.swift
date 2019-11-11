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

public extension EffectRouter where Input: Equatable {
    /// Route to an `EffectHandler` for all effects which are equal to `constant`.
    /// - Parameter constant: the constant to use for comparisons
    /// - Parameter handler: the effect handler which should handle `constant`
    func routeConstant(
        _ constant: Input,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter<Input, Output> {
        return add(
            path: { effect in effect == constant ? constant : nil },
            to: handler
        )
    }

    /// Route to an side-effecting function for all effects which are equal to `constant`.
    /// - Parameter constant: the constant to use for comparisons
    /// - Parameter fireAndForget: the function which should perform a side-effect
    func routeConstantToVoid(
        _ constant: Input,
        toVoid fireAndForget: @escaping () -> Void
    ) -> EffectRouter<Input, Output> {
        return add(
            path: { effect in effect == constant ? constant : nil },
            to: EffectHandler(
                handle: { _, _ in fireAndForget() },
                disposable: AnonymousDisposable {}
            )
        )
    }

    /// Route to a function which returns an event for all effects which are equal to `constant`.
    /// - Parameter constant: the constant to use for comparisons
    /// - Parameter outputFunction: the function which returns an event for the `constant`
    func routeConstantToEvent(
        _ constant: Input,
        toEvent outputFunction: @escaping () -> Output
    ) -> EffectRouter<Input, Output> {
        return add(
            path: { effect in effect == constant ? constant : nil },
            to: EffectHandler(
                handle: { _, dispatch in dispatch(outputFunction()) },
                disposable: AnonymousDisposable {}
            )
        )
    }
}

private func predicateToPath<Value>(_ predicate: @escaping (Value) -> Bool) -> ((Value) -> Value?) {
    return { value in predicate(value) ? value : nil }
}

public extension EffectRouter {
    /// Route to an `EffectHandler` for all effects which satisfy `predicate`.
    /// - Parameter predicate: the predicate function to use
    /// - Parameter handler: the effect handler which should handle effects satisfying `predicate`
    func routePredicate(
        _ predicate: @escaping (Input) -> Bool,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter<Input, Output> {
        return add(path: predicateToPath(predicate), to: handler)
    }

    /// Route to an side-effecting function for all effects which satisy `predicate`.
    /// - Parameter predicate: the predicate function to use
    /// - Parameter fireAndForget: the function which should perform a side-effect when the predicate is satisfied
    func routePredicateToVoid(
        _ predicate: @escaping (Input) -> Bool,
        toVoid fireAndForget: @escaping (Input) -> Void
    ) -> EffectRouter<Input, Output> {
        return add(
            path: predicateToPath(predicate),
            to: EffectHandler(
                handle: { effect, _ in fireAndForget(effect) },
                disposable: AnonymousDisposable {}
            )
        )
    }

    /// Route to a function which returns an event for all effects which satisfy `predicate`.
    /// - Parameter predicate: the predicate function to use
    /// - Parameter outputFunction: the function which returns an event for effects matching `predicate`
    func routePredicateToEvent(
        _ predicate: @escaping (Input) -> Bool,
        toEvent function: @escaping (Input) -> Output
    ) -> EffectRouter<Input, Output> {
        return add(
            path: predicateToPath(predicate),
            to: EffectHandler(
                handle: { effect, dispatch in dispatch(function(effect)) },
                disposable: AnonymousDisposable {}
            )
        )
    }
}

public extension EffectRouter {
    /// Route to an `EffectHandler` for all effects which satisfy `extractPayload`. An effect satisfies `extractPayload` if `extractPayload`
    /// returns a non-`nil` value for that effect. The returned value is sent to `handler`.
    /// - Parameter extractPayload: a function which returns a non-`nil` value containing the payload that `handler` should handle, or `nil` if
    /// another route should be taken instead.
    /// - Parameter handler: the effect handler which should handle effects satisfying `extractPayload`
    func routePayload<Payload>(
        _ extractPayload: @escaping (Input) -> Payload?,
        to handler: EffectHandler<Payload, Output>
    ) -> EffectRouter<Input, Output> {
        return add(
            path: extractPayload,
            to: handler
        )
    }

    /// Route to a side-effecting function for all effects which satisfy `extractPayload`. An effect satisfies `extractPayload` if `extractPayload`
    /// returns a non-`nil` value for that effect. The returned value is sent to `fireAndForget`.
    /// - Parameter extractPayload: a function which returns a non-`nil` value containing the payload that `fireAndForget` should handle, or
    ///  `nil` if another route should be taken instead.
    /// - Parameter fireAndForget: the side-effecting function to call with the result of all non-`nil` values returned by `extractPayload`
    func routePayloadToVoid<Payload>(
        _ extractPayload: @escaping (Input) -> Payload?,
        toVoid fireAndForget: @escaping (Payload) -> Void
    ) -> EffectRouter<Input, Output> {
        return add(
            path: extractPayload,
            to: EffectHandler(
                handle: { payload, _ in fireAndForget(payload) },
                disposable: AnonymousDisposable {}
            )
        )
    }

    /// Route to a function which returns events for all effects which satisfy `extractPayload`. An effect satisfies `extractPayload` if
    /// `extractPayload` returns a non-`nil` value for that effect. The returned value is sent to `function`.
    /// - Parameter extractPayload: a function which returns a non-`nil` value containing the payload that `function` should handle, or `nil` if
    /// another route should be taken instead.
    /// - Parameter function: the event-returning function to call with the result of all non-`nil` values returned by `extractPayload`
    func routePayloadToEvent<Payload>(
        _ extractPayload: @escaping (Input) -> Payload?,
        toEvent function: @escaping (Payload) -> Output
    ) -> EffectRouter<Input, Output> {
        return add(
            path: extractPayload,
            to: EffectHandler(
                handle: { payload, dispatch in dispatch(function(payload)) },
                disposable: AnonymousDisposable {}
            )
        )
    }
}
