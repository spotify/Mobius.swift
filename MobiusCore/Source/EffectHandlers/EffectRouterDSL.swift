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

public extension EffectRouter where Effect: Equatable {
    /// Add a route for effects which are equal to `constant`.
    ///
    /// - Parameter `constant`: the effect that should be handled by this route.
    func routeEffects(
        equalTo constant: Effect
    ) -> _PartialEffectRouter<Effect, Effect, Event> {
        return routeEffects(withParameters: { effect in effect == constant ? effect : nil })
    }
}

public extension _PartialEffectRouter {
    /// Route to the anonymous  `EffectHandler` defined by the `handle` closure.
    ///
    /// - Parameter handle: A closure which defines an `EffectHandler`.
    func to(
        _ handle: @escaping (EffectParameters, EffectCallback<Event>) -> Disposable
    ) -> EffectRouter<Effect, Event> {
        return to(AnyEffectHandler<EffectParameters, Event>(handle: handle))
    }

    /// Route to a side-effecting closure.
    ///
    /// - Parameter fireAndForget: a function which given some input carries out a side effect.
    func to(
        _ fireAndForget: @escaping (EffectParameters) -> Void
    ) -> EffectRouter<Effect, Event> {
        return to { parameters, callback in
            fireAndForget(parameters)
            callback.end()
            return AnonymousDisposable {}
        }
    }

    /// Route to a closure which returns an optional event when given the parameters as input.
    ///
    /// - Parameter eventClosure: a function which returns an optional event given some input. No events will be
    ///   propagated if this function returns `nil`.
    func toEvent(
        _ eventClosure: @escaping (EffectParameters) -> Event?
    ) -> EffectRouter<Effect, Event> {
        return to { parameters, callback in
            if let event = eventClosure(parameters) {
                callback.send(event)
            }
            callback.end()
            return AnonymousDisposable {}
        }
    }
}
