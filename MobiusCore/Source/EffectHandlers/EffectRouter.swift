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

public struct EffectRouter<Input, Output> {
    private let routes: [Route<Input, Output>]

    public init() {
        routes = []
    }

    fileprivate init(routes: [Route<Input, Output>]) {
        self.routes = routes
    }

    /// Add a route for effects which satisfy `payload`. `payload` is a function which returns an optional value for a given effect. If this value is non-`nil`
    /// this route will be taken with that non-`nil` value as input. A different route will be taken if `nil` is returned.
    /// - Parameter payload: a function which returns a non-`nil` value if this route should be taken, and `nil` if a different route should be taken.
    public func route<Payload>(
        payload: @escaping (Input) -> Payload?
    ) -> PartialEffectRouter<Input, Payload, Output> {
        return PartialEffectRouter(routes: routes, path: payload)
    }

    public var asConnectable: AnyConnectable<Input, Output> {
        return compose(routes: routes)
    }
}

public struct PartialEffectRouter<Input, Payload, Output> {
    fileprivate let routes: [Route<Input, Output>]
    fileprivate let path: (Input) -> Payload?

    /// Route to an `EffectHandler`.
    /// - Parameter effectHandler: the `EffectHandler` for the route in question.
    public func to(_ effectHandler: EffectHandler<Payload, Output>) -> EffectRouter<Input, Output> {
        let route = Route<Input, Output>(path: path, handler: effectHandler)
        return EffectRouter(routes: self.routes + [route])
    }
}

private struct Route<Input, Output> {
    let tryRoute: (Input, @escaping Consumer<Output>) -> Bool
    let disposable: Disposable

    init<Payload>(
        path tryPath: @escaping (Input) -> Payload?,
        handler: EffectHandler<Payload, Output>
    ) {
        tryRoute = { input, output in
            if let payload = tryPath(input) {
                handler.handle(payload, output)
                return true
            } else {
                return false
            }
        }
        disposable = handler.disposable
    }
}

private func compose<Effect, Event>(
    routes: [Route<Effect, Event>]
) -> AnyConnectable<Effect, Event> {
    return AnyConnectable { dispatch in
        let routeConnections = routes
            .map { route in toSafeConnection(route: route, dispatch: dispatch) }

        return Connection(
            acceptClosure: { effect in
                let handledCount = routeConnections
                    .map { $0.handle(effect) }
                    .filter { $0 }
                    .count

                if handledCount != 1 {
                    MobiusHooks.onError("Error: \(handledCount) EffectHandlers could be found for effect: \(handledCount). Exactly 1 is required.")
                }
            },
            disposeClosure: {
                routeConnections.forEach { route in
                    route.dispose()
                }
            }
        )
    }
}

private func toSafeConnection<Effect, Event>(
    route: Route<Effect, Event>,
    dispatch: @escaping Consumer<Event>
) -> PredicatedSafeConnection<Effect, Event> {
    return PredicatedSafeConnection(
        handleInput: route.tryRoute,
        output: dispatch,
        dispose: route.disposable
    )
}
