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

/// An `EffectRouter` defines the relationship between the effects in your domain and the constructs which handle those
/// effects.
///
/// - Note: Each effect in your domain must be linked to exactly one handler. A runtime crash will occur if zero or
/// multiple handlers were found for some received input.
///
/// To define the relationship between an effect and its handler, you need two parts. The first is the routing criteria.
///  There are two choices here:
///  - `.routeEffects(equalTo: constant)` - Routing to effects which are equal to `constant`.
///  - `.routeEffects(withParameters: extractParameters)` - Routing effects that satisfy
///     a parameter extracting function: `(Effect) -> EffectParameters?`. If this function returns a non-`nil` value,
///     that route is taken and the non-`nil` value is sent as the input to the route.
///
/// These two routing criteria can be matched with one of four types of targets:
///  - `.to { effect in ... }`: A fire-and-forget style function of type `(EffectParameters) -> Void`.
///  - `.toEvent { effect in ... }`: A function which returns an optional event to send back into the loop:
///    `(EffectParameters) -> Event?`. This makes it easy to send a single event caused by the effect.
///  - `.to(EffectHandler)`: This should be used for effects which require asynchronous behavior or produce more than
///     one event, and which have a clear definition of when an effect has been handled. For example, an effect handler
///     which performs a network request and dispatches an event back into the loop once it is finished or if it fails.
///  - `.to(Connectable)`: This should be used for effect handlers which do not have a clear definition of when a given
///     effect has been handled. For example, an effect handler which will continue to produce  events indefinitely once
///     it has been started.
public struct EffectRouter<Effect, Event> {
    private let routes: [Route<Effect, Event>]

    public init() {
        routes = []
    }

    fileprivate init(routes: [Route<Effect, Event>]) {
        self.routes = routes
    }

    /// Add a route for effects which satisfy `extractParameters`.
    ///
    /// `extractParameters` is a function which returns an optional value for a given effect. If this value is
    /// non-`nil`, this route will be taken with that non-`nil` value as input. A different route will be taken if `nil`
    /// is returned.
    ///
    /// - Parameter extractParameters: a function which returns a non-`nil` value if this route should be taken, and
    ///   `nil` if a different route should be taken.
    public func routeEffects<EffectParameters>(
        withParameters extractParameters: @escaping (Effect) -> EffectParameters?
    ) -> _PartialEffectRouter<Effect, EffectParameters, Event> {
        return _PartialEffectRouter(routes: routes, path: extractParameters)
    }

    /// Convert this `EffectRouter` into `Connectable` which can be attached to a Mobius Loop, or called on its own to
    /// handle effects.
    public var asConnectable: AnyConnectable<Effect, Event> {
        return compose(routes: routes)
    }
}

/// A `_PartialEffectRouter` represents the state between a `routeEffects` call and the corresponding `to` or `toEvent`.
///
/// Every `routeEffects` should be followed immediately by a `to` or `toEvent`, and client code should not refer to the
/// `_PartialEffectRouter` type directly.
public struct _PartialEffectRouter<Effect, EffectParameters, Event> {
    fileprivate let routes: [Route<Effect, Event>]
    fileprivate let path: (Effect) -> EffectParameters?

    /// Route to an `EffectHandler`.
    ///
    /// - Parameter effectHandler: the `EffectHandler` for the route in question.
    public func to<Handler: EffectHandler>(
        _ effectHandler: Handler
    ) -> EffectRouter<Effect, Event> where Handler.EffectParameters == EffectParameters, Handler.Event == Event {
        let connectable = EffectExecutor(handleInput: effectHandler.handle)
        let route = Route<Effect, Event>(extractParameters: path, connectable: connectable)
        return EffectRouter(routes: routes + [route])
    }

    /// Route to a Connectable.
    ///
    /// - Parameter connectable: a connectable which will be used to handle effects.
    public func to<C: Connectable>(
        _ connectable: C
    ) -> EffectRouter<Effect, Event> where C.Input == EffectParameters, C.Output == Event {
        let connectable = ThreadSafeConnectable(connectable: connectable)
        let route = Route(extractParameters: path, connectable: connectable)
        return EffectRouter(routes: routes + [route])
    }
}

private struct Route<Input, Output> {
    let connect: (@escaping Consumer<Output>) -> ConnectedRoute<Input>

    init<EffectParameters, Conn: Connectable>(
        extractParameters: @escaping (Input) -> EffectParameters?,
        connectable: Conn
    ) where Conn.Input == EffectParameters, Conn.Output == Output {
        connect = { output in
            let connection = connectable.connect(output)
            return ConnectedRoute(
                tryToHandle: { input in
                    if let parameters = extractParameters(input) {
                        return { connection.accept(parameters) }
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
                    MobiusHooks.errorHandler(
                        "Error: \(handlers.count) EffectHandlers could be found for effect: \(effect). " +
                        "Exactly 1 is required.",
                        #file,
                        #line
                    )
                }
            },
            disposeClosure: {
                connectedRoutes
                    .forEach { route in route.disposable.dispose() }
            }
        )
    }
}
