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
import MobiusCore
import Nimble

class SimpleTestConnectable: Connectable {
    typealias InputType = String
    typealias OutputType = String

    var disposed = false

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        return Connection<String>(acceptClosure: { _ in }, disposeClosure: { [weak self] in self?.disposed = true })
    }
}

class RecordingTestConnectable: Connectable {
    typealias InputType = String
    typealias OutputType = String

    private(set) var consumer: Consumer<String>?

    private(set) var recorder: Recorder<String>
    private(set) var connection: Connection<String>!
    var disposed: Bool = false

    init() {
        recorder = Recorder<String>()
    }

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        self.consumer = consumer
        connection = Connection(acceptClosure: accept, disposeClosure: dispose) // Will retain self
        return connection
    }

    func dispatch(_ string: String) {
        consumer?(string)
    }

    func accept(_ value: String) {
        recorder.items.append(value)
    }

    func dispose() {
        disposed = true
    }
}

class Recorder<T> {
    var items = [T]()
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
    var logMessages = [String]()

    func willInitiate(model: String) {
        logMessages.append("willInitiate(\(model))")
    }

    func didInitiate(model: String, first: First<String, String>) {
        logMessages.append("didInitiate(\(model), \(first))")
    }

    func willUpdate(model: String, event: String) {
        logMessages.append("willUpdate(\(model), \(event))")
    }

    func didUpdate(model: String, event: String, next: Next<String, String>) {
        logMessages.append("didUpdate(\(model), \(event), \(next))")
    }
}

class TestEventSource<Event>: EventSource {
    enum Subscription {
        case disposed
        case active(Consumer<Event>)
    }
    private(set) var subscriptions: [Subscription] = []

    func subscribe(consumer: @escaping Consumer<Event>) -> Disposable {
        let index = subscriptions.count
        subscriptions.append(.active(consumer))

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

    func dispatch(_ event: Event) {
        activeSubscriptions.forEach {
            $0(event)
        }
    }
}
