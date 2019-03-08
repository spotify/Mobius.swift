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

/// API for something that can be connected to be part of a MobiusLoop.
///
/// Primarily used in `Mobius.loop(update:effectHandler:)` to define the effect handler of a
/// Mobius loop. In that case, the incoming values will be effects, and the outgoing values will be
/// events that should be sent back to the loop.
///
/// Alternatively used in `MobiusController.connect(view:)` to connect a view to the
/// controller. In that case, the incoming values will be models, and the outgoing values will be
/// events.
///
/// Create a new connection that accepts input values and sends outgoing values to a supplied
/// consumer.
///
/// Must return a new `Connection` that accepts incoming values. After `dispose()` is called on
/// the returned `Connection`, the connection must be broken, and no more values may be sent
/// to the output consumer.
///
/// Every call to this method should create a new independent connection that can be disposed of
/// individually without affecting the other connections. If your Connectable doesn't support this,
/// it should throw an exception if someone tries to connect a second
/// time before disposing of the first connection.
/// - Parameter output: the consumer that the new connection should use to emit values
/// - Returns: a new connection
public protocol Connectable {
    associatedtype InputType
    associatedtype OutputType

    func connect(_ consumer: @escaping Consumer<OutputType>) -> Connection<InputType>
}

public typealias ConnectClosure<InputType, OutputType> = (@escaping Consumer<OutputType>) -> Connection<InputType>

public final class AnyConnectable<Input, Output>: Connectable {
    public typealias InputType = Input
    public typealias OutputType = Output

    private let connectClosure: ConnectClosure<Input, Output>

    public init<C: Connectable>(_ connectable: C) where C.InputType == Input, C.OutputType == Output {
        connectClosure = connectable.connect
    }

    public init(_ connectable: @escaping ConnectClosure<Input, Output>) {
        connectClosure = connectable
    }

    public func connect(_ consumer: @escaping Consumer<Output>) -> Connection<Input> {
        return connectClosure(consumer)
    }
}
