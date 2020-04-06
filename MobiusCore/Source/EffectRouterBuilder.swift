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

import Foundation

private typealias PredicatedConnectable<Input, Output> = (connect: (@escaping Consumer<Output>) -> Connection<Input>, predicate: (Input) -> Bool)
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
@available(*, deprecated, message: "use `EffectRouter` instead")
public struct EffectRouterBuilder<Input, Output> {
    private let connectables: [PredicatedConnectable<Input, Output>]

    public init() {
        self.init(connectables: [])
    }

    private init(connectables: [PredicatedConnectable<Input, Output>] = []) {
        self.connectables = connectables
    }

    func addConnectable<C: Connectable>(_ connectable: C, predicate: @escaping (Input) -> Bool) -> EffectRouterBuilder<Input, Output> where C.Input == Input, C.Output == Output {
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
        MobiusHooks.errorHandler("More than one effect handler handling effect: \(input)", #file, #line)
    }

    guard let (connection, _) = responders.first else {
        MobiusHooks.errorHandler("No effect handler is handling the effect: \(input)", #file, #line)
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
