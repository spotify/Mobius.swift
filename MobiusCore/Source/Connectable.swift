// Copyright 2019-2022 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// API for something that can be connected to be part of a MobiusLoop.
///
/// Primarily used in `Mobius.loop(update:effectHandler:)` to define the effect handler of a Mobius loop. In that case,
/// the incoming values will be effects, and the outgoing values will be events that should be sent back to the loop.
///
/// Alternatively used in `MobiusController.connectView(_:)` to connect a view to the controller. In that case, the
/// incoming values will be models, and the outgoing values will be events.
public protocol Connectable {
    associatedtype Input
    associatedtype Output

    /// Create a new connection that accepts input values and sends outgoing values to a supplied consumer.
    ///
    /// Must return a new `Connection` that accepts incoming values. After `dispose()` is called on the returned
    /// `Connection`, the connection must be broken, and no more values may be sent to the output consumer.
    ///
    /// Every call to this method should create a new independent connection that can be disposed of individually
    /// without affecting the other connections. If your `Connectable` doesn't support this, it should assert if someone
    /// tries to connect a second time before disposing of the first connection.
    ///
    /// - Parameter consumer: the consumer that the new connection should use to emit values
    /// - Returns: a new connection
    func connect(_ consumer: @escaping Consumer<Output>) -> Connection<Input>
}

/// Type-erased wrapper for `Connectable`s
public struct AnyConnectable<Input, Output>: Connectable {
    private let connectClosure: (@escaping Consumer<Output>) -> Connection<Input>

    /// Creates a type-erased `Connectable` that wraps the given instance.
    public init<C: Connectable>(_ connectable: C) where C.Input == Input, C.Output == Output {
        if let anyConnectable = connectable as? AnyConnectable {
            self = anyConnectable
        } else {
            self.init(connectable.connect)
        }
    }

    /// Creates an anonymous `Connectable` that implements `connect` with the provided closure.
    public init(_ connect: @escaping (@escaping Consumer<Output>) -> Connection<Input>) {
        connectClosure = connect
    }

    public func connect(_ consumer: @escaping Consumer<Output>) -> Connection<Input> {
        return connectClosure(consumer)
    }
}
