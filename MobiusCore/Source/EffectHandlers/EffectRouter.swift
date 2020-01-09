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

/// An `EffectRouter` defines the relationship between the effects in your domain and the constructs which
/// handle those effects.
///
/// To define the relationship between an effect and its handler, you need two parts.
/// The first is the routing criteria. There are two choices here:
///  - `.routeEffects(equalTo: constant)` - Routing to effects which are equal to `constant`.
///  - `.routeEffects(withPayload: extractPayload)` - Routing effects that satisfy
///     a payload extracting function: `(Effect) -> Payload?`. If this function returns a non-`nil` value,
///     that route is taken and the non-`nil` value is sent as the input to the route.
///
/// These two routing criteria can be matched with one of four types of targets:
///  - `.to { effect in ... }` - A fire-and-forget style function of type `(Effect) -> Void`.
///  - `.toEvent { effect in ... }` A function which returns an optional event to send back into
///     the loop: `(Effect) -> Event?`.
///  - `.to(EffectHandler)` This should be used for effects which require asynchronous behavior
///     or produce more than one event, and which have a clear definition of when an effect has been handled.
///     For example, an effect handler which performs a network request and dispatches an event back into the
///     loop once it is finished or if it fails.
///  - `.to(Connectable)` This should be used for effect handlers which do not have a clear definition of
///     when a given effect has been handled. For example, an effect handler which will continue to produce
///     events indefinitely once it has been started.
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

    /// Convert this `EffectRouter` into `Connectable` which can be attached to a Mobius Loop, or called on its own to handle effects.
    ///
    /// Note: Each instance of `Input` must have been linked to exactly one handler. A runtime crash will occur if zero or multiple handlers were found for some
    /// received input.
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
