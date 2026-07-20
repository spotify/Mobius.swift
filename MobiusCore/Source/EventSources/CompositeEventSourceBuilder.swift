// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

/// A `CompositeEventSourceBuilder` gathers the provided event sources together and builds a single event source that
/// subscribes to all of them when its `subscribe` method is called.
public struct CompositeEventSourceBuilder<Event> {
    private let eventSources: [AnyEventSource<Event>]

    /// Initializes a `CompositeEventSourceBuilder`.
    public init() {
        self.init(eventSources: [])
    }

    private init(eventSources: [AnyEventSource<Event>]) {
        self.eventSources = eventSources
    }

    /// Returns a new `CompositeEventSourceBuilder` with the specified event source added to it.
    public func addEventSource<Source: EventSource>(_ source: Source)
    -> CompositeEventSourceBuilder<Event> where Source.Event == Event {
        let sources = eventSources + [AnyEventSource(source)]
        return CompositeEventSourceBuilder(eventSources: sources)
    }

    /// Builds an event source that composes all the event sources that have been added to the builder.
    ///
    /// - Returns: An event source which represents the composition of the builder’s input event sources. The type
    /// of this source is an implementation detail; consumers should avoid spelling it out if possible.
    public func build() -> AnyEventSource<Event> {
        switch eventSources.count {
        case 0:
            return AnyEventSource { _ in AnonymousDisposable {} }
        case 1:
            return eventSources[0]
        default:
            let eventSources = self.eventSources
            return AnyEventSource { consumer in
                let disposables = eventSources.map {
                    $0.subscribe(consumer: consumer)
                }
                return CompositeDisposable(disposables: disposables)
            }
        }
    }
}
