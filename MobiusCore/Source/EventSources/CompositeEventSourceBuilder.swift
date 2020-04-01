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
        let sources = eventSources + [AnyEventSource<Event>(source)]
        return CompositeEventSourceBuilder(eventSources: sources)
    }

    /// Builds an event source that composes all the event sources that have been added to the builder.
    ///
    /// - Returns: An event source which represents the composition of the builder’s input event sources. The type
    /// of this source is an implementation detail; consumers should avoid spelling it out if possible.
    public func build() -> AnyEventSource<Event> {
        switch eventSources.count {
        case 0:
            return AnyEventSource<Event> { _ in AnonymousDisposable {} }
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
