// Copyright 2019-2024 Spotify AB.
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

final class ThreadSafeConnectable<Event, Effect>: Connectable {
    private let connectable: AnyConnectable<Effect, Event>
    private let outputQueue: DispatchQueue?

    private let lock = Lock()
    private var output: Consumer<Event>?
    private var connection: Connection<Effect>?

    init<Conn: Connectable>(
        connectable: Conn,
        outputQueue: DispatchQueue? = nil
    ) where Conn.Input == Effect, Conn.Output == Event {
        self.connectable = AnyConnectable(connectable)
        self.outputQueue = outputQueue
    }

    func connect(_ output: @escaping (Event) -> Void) -> Connection<Effect> {
        return lock.synchronized {
            guard self.output == nil, connection == nil else {
                MobiusHooks.errorHandler(
                    "Connection limit exceeded: The Connectable \(type(of: self)) is already connected. " +
                    "Unable to connect more than once",
                    #file,
                    #line
                )
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
        if let connection = lock.synchronized(closure: { connection }) {
            connection.accept(effect)
        }
    }

    private func dispatch(event: Event) {
        if let outputQueue = outputQueue {
            outputQueue.async { [weak self] in self?.synchronizedDispatch(event: event) }
        } else {
            synchronizedDispatch(event: event)
        }
    }

    private func synchronizedDispatch(event: Event) {
        if let output = lock.synchronized(closure: { output }) {
            output(event)
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
