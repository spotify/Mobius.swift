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
    func route(
        constant: Input
    ) -> PartialEffectRouter<Input, Input, Output> {
        return route(payload: { effect in effect == constant ? constant : nil })
    }
}

public extension EffectRouter {
    func route(
        predicate: @escaping (Input) -> Bool
    ) -> PartialEffectRouter<Input, Input, Output> {
        return route(payload: { effect in predicate(effect) ? effect : nil })
    }
}

public extension PartialEffectRouter {
    func to(
        _ fireAndForget: @escaping (Payload) -> Void
    ) -> EffectRouter<Input, Output> {
        return to(EffectHandler<Payload, Output>(
            handle: { payload, _ in fireAndForget(payload) },
            disposable: AnonymousDisposable {}
        ))
    }

    func toEvent(
        _ eventFunction: @escaping (Payload) -> Output
    ) -> EffectRouter<Input, Output> {
        return to(EffectHandler<Payload, Output>(
            handle: { payload, dispatch in dispatch(eventFunction(payload)) },
            disposable: AnonymousDisposable {}
        ))
    }
}
