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
@testable import MobiusCore
import Nimble

class SimpleTestConnectable: Connectable {
    var disposed = false

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        return Connection(acceptClosure: { _ in }, disposeClosure: { [weak self] in self?.disposed = true })
    }
}

class RecordingTestConnectable: Connectable {
    private(set) var consumer: Consumer<String>?

    private(set) var recorder: Recorder<String>
    private(set) var connection: Connection<String>!
    var disposed: Bool = false

    private let expectedQueue: DispatchQueue?

    init(expectedQueue: DispatchQueue? = nil) {
        recorder = Recorder()
        self.expectedQueue = expectedQueue
    }

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        self.consumer = consumer
        connection = Connection(acceptClosure: accept, disposeClosure: dispose) // Will retain self
        return connection
    }

    func dispatch(_ string: String) {
        if let queue = self.expectedQueue {
            queue.sync { consumer?(string) }
        } else {
            consumer?(string)
        }
    }

    func dispatchSameQueue(_ string: String) {
        verifyQueue()
        consumer?(string)
    }

    func accept(_ value: String) {
        verifyQueue()

        recorder.append(value)
    }

    func dispose() {
        disposed = true
    }

    private func verifyQueue() {
        if let expectedQueue = expectedQueue {
            dispatchPrecondition(condition: .onQueue(expectedQueue))
        }
    }
}

final class Recorder<T> {
    private var storage = Synchronized<[T]>(value: [])
    private let queue = DispatchQueue(label: "Recorder")

    var items: [T] {
        return storage.value
    }

    func append(_ item: T) {
        storage.mutate {
            $0.append(item)
        }
    }

    func clear() {
        storage.value = []
    }
}

class TestDisposable: Disposable {
    var disposed = false

    func dispose() {
        disposed = true
    }
}

extension DispatchQueue {
    static func testQueue(_ label: String) -> DispatchQueue {
        return DispatchQueue(label: label, attributes: .concurrent)
    }

    func waitForOutstandingTasks() {
        sync(flags: .barrier) {}
    }
}

class TestMobiusLogger: MobiusLogger {
    private var messages = Synchronized<[String]>(value: [])

    private func appendLog(_ log: String) {
        messages.mutate {
            $0.append(log)
        }
    }

    public var logMessages: [String] {
        return messages.value
    }

    func clear() {
        messages.value = []
    }

    func willInitiate(model: String) {
        appendLog("willInitiate(\(model))")
    }

    func didInitiate(model: String, first: First<String, String>) {
        appendLog("didInitiate(\(model), \(first))")
    }

    func willUpdate(model: String, event: String) {
        appendLog("willUpdate(\(model), \(event))")
    }

    func didUpdate(model: String, event: String, next: Next<String, String>) {
        appendLog("didUpdate(\(model), \(event), \(next))")
    }
}

class TestEventSource<Event>: EventSource {
    enum Subscription {
        case disposed
        case active(Consumer<Event>)
    }
    private(set) var subscriptions: [Subscription] = []
    private var pendingEvent: Event?

    func subscribe(consumer: @escaping Consumer<Event>) -> Disposable {
        let index = subscriptions.count
        subscriptions.append(.active(consumer))

        if let event = pendingEvent {
            consumer(event)
            pendingEvent = nil
        }

        return AnonymousDisposable { [weak self] in
            self?.subscriptions[index] = .disposed
        }
    }

    var activeSubscriptions: [Consumer<Event>] {
        return subscriptions.compactMap {
            switch $0 {
            case .disposed:
                return nil
            case .active(let consumer):
                return consumer
            }
        }
    }

    var allDisposed: Bool {
        return activeSubscriptions.isEmpty
    }

    // Set an event to dispatch immediately when subscribed
    func dispatchOnSubscribe(_ event: Event) {
        pendingEvent = event
    }

    func dispatch(_ event: Event) {
        activeSubscriptions.forEach {
            $0(event)
        }
    }
}

class TestConnectableEventSource<Model, Event>: Connectable {
    typealias Input = Model
    typealias Output = Event

    enum Connection {
        case disposed
        case active(Consumer<Event>)
    }
    private(set) var connections: [Connection] = []
    private(set) var models: [Model] = []
    private var pendingEvent: Event?
    var modelSwitch: ((Model) -> Bool)?

    var activeConnections: [Consumer<Event>] {
        return connections.compactMap {
            switch $0 {
            case .disposed:
                return nil
            case .active(let consumer):
                return consumer
            }
        }
    }

    var allDisposed: Bool {
        return activeConnections.isEmpty
    }

    func connect(_ consumer: @escaping MobiusCore.Consumer<Event>) -> MobiusCore.Connection<Model> {
        let index = connections.count
        connections.append(.active(consumer))

        if let event = pendingEvent {
            consumer(event)
            pendingEvent = nil
        }

        return .init(
            acceptClosure: { [weak self] model in
                let shouldProcessModel = self?.modelSwitch?(model) ?? false
                if shouldProcessModel {
                    self?.models.append(model)
                }
            }, disposeClosure: { [weak self] in
                self?.connections[index] = .disposed
            }
        )
    }

    // Set an event to dispatch immediately when subscribed
    func dispatchOnSubscribe(_ event: Event) {
        pendingEvent = event
    }

    func dispatch(_ event: Event) {
        activeConnections.forEach {
            $0(event)
        }
    }
}
