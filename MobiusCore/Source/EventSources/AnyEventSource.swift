// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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
