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
    /// Add a route for effects which are equal to `equalTo`.
    /// - Parameter `equalTo`: the effect that should be handled by this route
    func routeEffects(
        equalTo constant: Input
    ) -> PartialEffectRouter<Input, Input, Output> {
        return routeEffects(withPayload: { effect in effect == constant ? effect : nil })
    }
}

public extension PartialEffectRouter {
    /// Route to a side-effecting closure.
    /// - Parameter fireAndForget: a function which given some input carries out a side effect.
    func to(
        _ fireAndForget: @escaping (Payload) -> Void
    ) -> EffectRouter<Input, Output> {
        return to(AnyEffectHandler<Payload, Output> { payload, _ in
            fireAndForget(payload)
            return AnonymousDisposable {}
        })
    }

    /// Route to a closure which returns an optional event when given the payload as input.
    /// - Parameter eventFunction: a function which returns an optional event given some input. No events will be propagated if this function returns
    /// `nil`.
    func toEvent(
        _ eventFunction: @escaping (Payload) -> Output?
    ) -> EffectRouter<Input, Output> {
        return to(AnyEffectHandler<Payload, Output> { payload, dispatch in
            if let event = eventFunction(payload) {
                dispatch(event)
            }
            return AnonymousDisposable {}
        })
        
    }

    /// Route to a side-effecting closure.
    /// - Parameter connectable: a connectable which will be used to handle effects
    func to<C: Connectable>(
        _ connectable: C
    ) -> EffectRouter<Input, Output> where C.InputType == Payload, C.OutputType == Output {
        var connection: Connection<Payload>?
        return to(AnyEffectHandler<Payload, Output>(
            handle: { payload, output in
                connection = connection ?? connectable.connect(output)
                connection?.accept(payload)
                return AnonymousDisposable {
                    connection?.dispose()
                }
            }
        ))
    }
}
