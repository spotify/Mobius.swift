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

final class ThreadSafeConnectable<Event, Effect>: Connectable {
    private let connectable: AnyConnectable<Effect, Event>

    private let lock = Lock()
    private var output: Consumer<Event>?
    private var connection: Connection<Effect>?

    init<Conn: Connectable>(
        connectable: Conn
    ) where Conn.InputType == Effect, Conn.OutputType == Event {
        self.connectable = AnyConnectable(connectable)
    }

    func connect(_ output: @escaping (Event) -> Void) -> Connection<Effect> {
        return lock.synchronized {
            guard self.output == nil, connection == nil else {
                MobiusHooks.onError("ConnectionLimitExceeded: The Connectable \(type(of: self)) is already connected. Unable to connect more than once")
                return BrokenConnection.connection()
            }
            self.output = output
            connection = connectable.connect(self.dispatch)

            return Connection(
                acceptClosure: accept,
                disposeClosure: dispose
            )
        }
    }

    private func accept(_ effect: Effect) {
        lock.synchronized {
            connection?.accept(effect)
        }
    }

    private func dispatch(event: Event) {
        lock.synchronized {
            output?(event)
        }
    }

    private func dispose() {
        var disposeConnection: (() -> Void)?
        lock.synchronized {
            output = nil
            disposeConnection = connection?.dispose
            connection = nil
        }
        disposeConnection?()
    }

    deinit {
        dispose()
    }
}
