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

public extension First where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    init(model: Model, effects: Set<Effect>) {
        self.model = model
        self.effects = Array(effects)
    }
}

public extension Next where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    static func next(_ model: Model, effects: Set<Effect>) -> Next<Model, Effect> {
        return .next(model, effects: Array(effects))
    }

    @available(*, deprecated, message: "use array of effects instead")
    static func dispatchEffects(_ effects: Set<Effect>) -> Next<Model, Effect> {
        return .dispatchEffects(Array(effects))
    }
}

public extension MobiusLoop {
    @available(*, deprecated, message: "use latestModel of effects instead")
    func getMostRecentModel() -> Model? {
        return latestModel
    }
}
@available(*, deprecated, message: "use `EffectHandler` instead")
public protocol EffectPredicate {
    associatedtype Effect
    func canAccept(_ effect: Effect) -> Bool
}

@available(*, deprecated, message: "use `EffectHandler` instead")
public protocol ConnectableWithPredicate: Connectable, EffectPredicate {}

@available(*, deprecated, message: "use `EffectHandler` instead")
public protocol ConsumerWithPredicate: EffectPredicate {
    func accept(_ effect: Effect)
}

@available(*, deprecated, message: "use `EffectHandler` instead")
public protocol ActionWithPredicate: EffectPredicate {
    func run()
}

@available(*, deprecated, message: "use `EffectHandler` instead")
public protocol FunctionWithPredicate: EffectPredicate {
    associatedtype Event

    func apply(_ effect: Effect) -> Event
}

private typealias PredicatedConnectable<Input, Output> = (connect: ConnectClosure<Input, Output>, predicate: (Input) -> Bool)
private typealias PredicatedConnection<Input> = (connection: Connection<Input>, predicate: (Input) -> Bool)

/// Builder for an effect handler that routes to different sub-handlers based on effect type.
///
/// Register handlers for different cases of `T.Effect` using the `add` methods, and call `build`
/// to create an instance of the effect handler. You can then create a loop with the router
/// as the effect handler using Mobius's `loop(update:effectHandler:)`.
///
/// The router will look at each of the incoming effects and try to find a registered
/// handler for that particular effect. If a handler is found, it will be given the effect
/// object, otherwise an error will be passed to the `MobiusHooks` error function.
///
/// All the classes that the effect router know about must have a common type T.Effect. Note that
/// instances of the builder are mutable and not thread-safe.
@available(*, deprecated, message: "use `EffectHandler` instead")
public struct EffectRouterBuilder<Input, Output> {
    private let connectables: [PredicatedConnectable<Input, Output>]

    public init() {
        self.init(connectables: [])
    }

    private init(connectables: [PredicatedConnectable<Input, Output>] = []) {
        self.connectables = connectables
    }

    /// Add an `EffectHandler` which will be connected for each incoming effect object that passes its `canAccept` call.
    ///
    /// - Parameters:
    ///   - effectHandler: The `EffectHandler` which should be added to this builder.
    /// - Returns: This builder.
    public func addEffectHandler(
        _ effectHandler: EffectHandler<Input, Output>
    ) -> EffectRouterBuilder<Input, Output> {
        let handler = (connect: effectHandler.connect, predicate: { effect in
            effectHandler.canHandle(effect) != nil
        })
        return EffectRouterBuilder<Input, Output>(connectables: connectables + [handler])
    }

    func addConnectable<C: Connectable>(_ connectable: C, predicate: @escaping (Input) -> Bool) -> EffectRouterBuilder<Input, Output> where C.InputType == Input, C.OutputType == Output {
        let handler = (connect: connectable.connect, predicate: predicate)
        return EffectRouterBuilder<Input, Output>(connectables: connectables + [handler])
    }

    /// Add a filtered `Connectable` for handling effects of a given type. The `Connectable` `Connection` will be invoked for
    /// each incoming effect object that passes its `canAccept` call.
    ///
    /// - Parameters:
    ///   - connectable: The `Connectable` which handles an effect
    /// - Returns: This builder.
    public func addConnectable<C: Connectable & EffectPredicate>(_ connectable: C) -> EffectRouterBuilder<Input, Output> where C.InputType == Input, C.OutputType == Output, C.Effect == Input {
        return addConnectable(connectable, predicate: connectable.canAccept)
    }

    // If `function` produces an output that is not nil, it will be passed to the connected consumer. If nil is produced
    // it will not be passed to the consumer
    public func addFunction(_ function: @escaping (Input) -> Output?, predicate: @escaping (Input) -> Bool) -> EffectRouterBuilder<Input, Output> {
        let connectable = ClosureConnectable<Input, Output>(function)
        return addConnectable(connectable, predicate: predicate)
    }

    public func addFunction<F: FunctionWithPredicate>(_ function: F, queue: DispatchQueue? = nil) -> EffectRouterBuilder<Input, Output> where F.Effect == Input, F.Event == Output {
        let connectable = ClosureConnectable<Input, Output>(function.apply, queue: queue)
        return addConnectable(connectable, predicate: function.canAccept)
    }

    public func addConsumer<C: ConsumerWithPredicate>(_ consumer: C, queue: DispatchQueue? = nil) -> EffectRouterBuilder<Input, Output> where C.Effect == Input {
        let connectable = ClosureConnectable<Input, Output>(consumer.accept, queue: queue)
        return addConnectable(connectable, predicate: consumer.canAccept)
    }

    public func addAction<A: ActionWithPredicate>(_ action: A, queue: DispatchQueue? = nil) -> EffectRouterBuilder<Input, Output> where A.Effect == Input {
        let connectable = ClosureConnectable<Input, Output>(action.run, queue: queue)
        return addConnectable(connectable, predicate: action.canAccept)
    }

    /// Builds an effect router `Connectable` based on this configuration.
    ///
    /// - Returns: A new `Connectable`.
    public func build() -> AnyConnectable<Input, Output> {
        return mergedConnectables()
    }

    private func mergedConnectables() -> AnyConnectable<Input, Output> {
        let connectables = self.connectables
        let mergedConnectable = { (consumer: @escaping Consumer<Output>) -> Connection<Input> in
            let connections = createConnections(connectables, consumer)
            return mergedConnections(connections)
        }
        return AnyConnectable<Input, Output>(mergedConnectable)
    }
}

private func createConnections<Input, Output>(_ connectables: [PredicatedConnectable<Input, Output>], _ consumer: @escaping Consumer<Output>) -> [PredicatedConnection<Input>] {
    let filteredConnections = connectables.map { (connectable: PredicatedConnectable<Input, Output>) -> PredicatedConnection<Input> in
        (connectable.connect(consumer), connectable.predicate)
    }

    return filteredConnections
}

private func mergedConnections<Input>(_ connections: [PredicatedConnection<Input>]) -> Connection<Input> {
    let lock = Lock()

    let connection = Connection<Input>(
        acceptClosure: { (input: Input) in
            lock.synchronized {
                dispatchAccept(connections, input)
            }
        },
        disposeClosure: {
            lock.synchronized {
                dispatchDispose(connections)
            }
        }
    )

    return connection
}

private func dispatchAccept<Input>(_ connections: [PredicatedConnection<Input>], _ input: Input) {
    let responders = selectConnections(connections, respondingTo: input)

    if responders.count > 1 {
        MobiusHooks.onError("More than one effect handler handling effect: \(input)")
        return
    }

    guard let (connection, _) = responders.first else {
        MobiusHooks.onError("No effect handler is handling the effect: \(input)")
        return
    }

    connection.accept(input)
}

private func selectConnections<Input>(_ connections: [PredicatedConnection<Input>], respondingTo input: Input) -> [PredicatedConnection<Input>] {
    let filtered = connections.filter({ filteredConnection -> Bool in
        filteredConnection.predicate(input)
    })

    return filtered
}

private func dispatchDispose<Input>(_ connections: [PredicatedConnection<Input>]) {
    connections.forEach({ (filteredConnection: PredicatedConnection<Input>) in
        filteredConnection.connection.dispose()
    })
}

public extension Mobius {
    /// Create a `Builder` to help you configure a `MobiusLoop ` before starting it.
    ///
    /// The builder is immutable. When setting various properties, a new instance of a builder will be returned.
    /// It is therefore recommended to chain the loop configuration functions
    ///
    /// Once done configuring the loop you can start the loop using `start(from:)`.
    ///
    /// - Parameters:
    ///   - update: the `Update` function of the loop
    ///   - effectHandler: an instance conforming to the `ConnectableProtocol`. Will be used to handle effects by the loop
    /// - Returns: a `Builder` instance that you can further configure before starting the loop
    @available(*, deprecated, message: "create the loop with an `EffectHandler` instead")
    static func loop<Model, Event, Effect, C: Connectable>(update: @escaping Update<Model, Event, Effect>, effectHandler: C) -> Builder<Model, Event, Effect> where C.InputType == Effect, C.OutputType == Event {
        return Builder(
            update: update,
            effectHandler: effectHandler,
            initiator: { First(model: $0) },
            eventSource: AnyEventSource({ _ in AnonymousDisposable(disposer: {}) }),
            eventQueue: DispatchQueue(label: "event processor"),
            effectQueue: DispatchQueue(label: "effect processor", attributes: .concurrent),
            logger: AnyMobiusLogger(NoopLogger())
        )
    }
}
