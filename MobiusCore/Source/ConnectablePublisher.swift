// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Internal class that provides a 'publisher' for connectables; that is, something that you can post values to, and
/// that will broadcast posted values to all connections. It also retains a current value, and will post that value to
/// new connections.
final class ConnectablePublisher<Value>: Disposable {
    private let access: ConcurrentAccessDetector
    private var connections = [UUID: Connection<Value>]()
    private var currentValue: Value?
    private var _disposed = false

    init(accessGuard: ConcurrentAccessDetector = ConcurrentAccessDetector()) {
        access = accessGuard
    }

    var disposed: Bool {
        return access.guard { _disposed }
    }

    func post(_ value: Value) {
        let connections: [Connection<Value>] = access.guard {
            guard !disposed else {
                // Callers are responsible for ensuring post is never entered after dispose.
                MobiusHooks.errorHandler(
                    "ConnectablePublisher<\(Value.self)> cannot accept values when disposed",
                    #file,
                    #line
                )
            }

            currentValue = value

            return Array(self.connections.values)
        }

        // Note that we froze the list of connections in the sync block, but dispatch accept here to avoid any
        // risk of recursion.
        connections.forEach { $0.accept(value) }
    }

    @discardableResult
    func connect(to outputConsumer: @escaping Consumer<Value>) -> Connection<Value> {
        return access.guard { () -> Connection<Value> in
            guard !_disposed else {
                // Callers are responsible for ensuring connect is never entered after dispose.
                MobiusHooks.errorHandler(
                    "ConnectablePublisher<\(Value.self)> cannot add connections when disposed",
                    #file,
                    #line
                )
            }

            let uuid = UUID()
            let connection = Connection(acceptClosure: outputConsumer, disposeClosure: { [weak self] in self?.removeConnection(for: uuid) })

            self.connections[uuid] = connection

            if let value = currentValue {
                outputConsumer(value)
            }

            return connection
        }
    }

    func dispose() {
        let connections: [Connection<Value>] = access.guard {
            guard !_disposed else { return [] }

            _disposed = true
            return Array(self.connections.values)
        }

        // Again, this has to be outside the sync block to avoid recursive locking – in this case, recursion into
        // removeConnection().
        connections.forEach { $0.dispose() }
    }

    private func removeConnection(for uuid: UUID) {
        access.guard {
            self.connections[uuid] = nil
        }
    }
}
