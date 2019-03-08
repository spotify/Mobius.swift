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

/// Internal class that provides a 'publisher' for connectables; that is, something that you can post values to, and that
/// will broadcast posted values to all connections. It also retains a current value, and will post that value to new
/// connections.
class ConnectablePublisher<ValueType>: Disposable {
    private var connections = [UUID: Connection<ValueType>]()
    private var currentValue: ValueType?

    // AtomicBool is used here to ensure coherence in the event that dispose and dispatchEvent are
    // called on different threads.
    private var disposed = AtomicBool(false)
    var isDisposed: Bool {
        return disposed.value
    }

    func post(_ value: ValueType) {
        guard !disposed.value else {
            // Callers are responsible for ensuring post is never entered after dispose.
            MobiusHooks.onError("cannot accept values when disposed")
            return
        }

        currentValue = value

        connections.values.forEach({ $0.accept(value) })
    }

    @discardableResult
    func connect(to outputConsumer: @escaping Consumer<ValueType>) -> Connection<ValueType> {
        guard !disposed.value else {
            // Callers are responsible for ensuring connect is never entered after dispose.
            MobiusHooks.onError("cannot add connections when disposed")
            return BrokenConnection<ValueType>.connection()
        }

        let uuid = UUID()
        let connection = Connection(acceptClosure: outputConsumer, disposeClosure: { [weak self] in self?.connections[uuid] = nil })

        connections[uuid] = connection

        if let value = currentValue {
            outputConsumer(value)
        }

        return connection
    }

    func dispose() {
        let alreadyDisposed = disposed.getAndSet(value: true)

        if !alreadyDisposed {
            connections.values.forEach({ $0.dispose() })
            connections.removeAll()
        }
    }
}
