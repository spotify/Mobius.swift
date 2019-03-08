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

public protocol EffectPredicate {
    associatedtype Effect
    func canAccept(_ effect: Effect) -> Bool
}

public protocol ConnectableWithPredicate: Connectable, EffectPredicate {}

public protocol ConsumerWithPredicate: EffectPredicate {
    func accept(_ effect: Effect)
}

public protocol ActionWithPredicate: EffectPredicate {
    func run()
}

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
public struct EffectRouterBuilder<Input, Output> {
    private let connectables: [PredicatedConnectable<Input, Output>]

    public init() {
        self.init(connectables: [])
    }

    private init(connectables: [PredicatedConnectable<Input, Output>] = []) {
        self.connectables = connectables
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
    func addFunction(_ function: @escaping (Input) -> Output?, predicate: @escaping (Input) -> Bool) -> EffectRouterBuilder<Input, Output> {
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

    private func addConnectable<C: Connectable>(_ connectable: C, predicate: @escaping (Input) -> Bool) -> EffectRouterBuilder<Input, Output> where C.InputType == Input, C.OutputType == Output {
        let handler = (connect: connectable.connect, predicate: predicate)
        return EffectRouterBuilder<Input, Output>(connectables: connectables + [handler])
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
    let lock = NSRecursiveLock()

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
