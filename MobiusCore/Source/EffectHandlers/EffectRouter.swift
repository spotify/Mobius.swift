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

    /// Add a route for effects which satisfy `withPayload`. `withPayload` is a function which returns an optional value for a given effect. If this value is
    /// non-`nil` this route will be taken with that non-`nil` value as input. A different route will be taken if `nil` is returned.
    /// - Parameter withPayload: a function which returns a non-`nil` value if this route should be taken, and `nil` if a different route should be taken.
    public func routeEffects<Payload>(
        withPayload payload: @escaping (Input) -> Payload?
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
    public func to<Handler: EffectHandler>(
        _ effectHandler: Handler
    ) -> EffectRouter<Input, Output> where Handler.Effect == Payload, Handler.Event == Output {
        let connectable = EffectExecutor(handleInput: effectHandler.handle)
        let route = Route<Input, Output>(extractPayload: path, connectable: connectable)
        return EffectRouter(routes: routes + [route])
    }

    /// Route to a Connectable.
    /// - Parameter connectable: a connectable which will be used to handle effects
    public func to<C: Connectable>(
        _ connectable: C
    ) -> EffectRouter<Input, Output> where C.InputType == Payload, C.OutputType == Output {
        let connectable = ThreadSafeConnectable(connectable: connectable)
        let route = Route(extractPayload: path, connectable: connectable)
        return EffectRouter(routes: routes + [route])
    }
}

private struct Route<Input, Output> {
    let connect: (@escaping Consumer<Output>) -> ConnectedRoute<Input>

    init<Payload, Conn: Connectable>(
        extractPayload: @escaping (Input) -> Payload?,
        connectable: Conn
    ) where Conn.InputType == Payload, Conn.OutputType == Output {
        connect = { output in
            let connection = connectable.connect(output)
            return ConnectedRoute(
                tryToHandle: { input in
                    if let payload = extractPayload(input) {
                        return { connection.accept(payload) }
                    } else {
                        return nil
                    }
                },
                disposable: connection
            )
        }
    }
}

private struct ConnectedRoute<Input> {
    let tryToHandle: (Input) -> (() -> Void)?
    let disposable: Disposable
}

private func compose<Input, Output>(
    routes: [Route<Input, Output>]
) -> AnyConnectable<Input, Output> {
    return AnyConnectable { output in
        let connectedRoutes = routes
            .map { route in route.connect(output) }

        return Connection(
            acceptClosure: { effect in
                let handlers = connectedRoutes
                    .compactMap { route in route.tryToHandle(effect) }

                if let handleEffect = handlers.first, handlers.count == 1 {
                    handleEffect()
                } else {
                    MobiusHooks.onError("Error: \(handlers.count) EffectHandlers could be found for effect: \(effect). Exactly 1 is required.")
                }
            },
            disposeClosure: {
                connectedRoutes
                    .forEach { route in route.disposable.dispose() }
            }
        )
    }
}
