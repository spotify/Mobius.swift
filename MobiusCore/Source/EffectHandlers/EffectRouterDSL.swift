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
    func routeConstant(
        _ constant: Input,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter<Input, Output> {
        return add(
            path: { effect in effect == constant ? constant : nil },
            to: handler
        )
    }

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
    func routePredicate(
        _ predicate: @escaping (Input) -> Bool,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter<Input, Output> {
        return add(path: predicateToPath(predicate), to: handler)
    }

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
    func routePayload<Payload>(
        _ extractPayload: @escaping (Input) -> Payload?,
        to handler: EffectHandler<Payload, Output>
    ) -> EffectRouter<Input, Output> {
        return add(
            path: extractPayload,
            to: handler
        )
    }

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
