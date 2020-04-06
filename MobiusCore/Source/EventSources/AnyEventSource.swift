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

/// The `AnyEventSource` class implements a `EventSource` type that sends events to subscribers.
public final class AnyEventSource<Event>: EventSource {
    private let subscribeClosure: (@escaping Consumer<Event>) -> Disposable

    /// Creates a type-erased `EventSource` that wraps the given instance.
    public convenience init<Source: EventSource>(_ eventSource: Source) where Source.Event == Event {
        let subscribeClosure: (@escaping Consumer<Event>) -> Disposable

        if let anyEventSource = eventSource as? AnyEventSource {
            subscribeClosure = anyEventSource.subscribeClosure
        } else {
            subscribeClosure = eventSource.subscribe
        }

        self.init(subscribeClosure)
    }

    /// Creates an anonymous `EventSource` that implements `subscribe` with the provided closure.
    public init(_ subscribe: @escaping (@escaping Consumer<Event>) -> Disposable) {
        subscribeClosure = subscribe
    }

    public func subscribe(consumer eventConsumer: @escaping Consumer<Event>) -> Disposable {
        return subscribeClosure(eventConsumer)
    }
}
