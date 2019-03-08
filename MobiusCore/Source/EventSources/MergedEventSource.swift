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

/// A `MergedEventSource` holds onto the provided event sources and subscribes consumers to all of them once its
/// `subscribe` method is called.
public final class MergedEventSource<Event>: EventSource {
    private let eventSources: [AnyEventSource<Event>]

    /// Initialises a MergedEventSource
    ///
    /// - Parameter eventSources: an array of `EventSource` with matching `Events`
    public init<ES: EventSource>(eventSources: [ES]) where ES.Event == Event {
        self.eventSources = eventSources.map({ (eventSource: ES) -> AnyEventSource<Event> in
            AnyEventSource<Event>(eventSource)
        })
    }

    /// Subscribes a consumer to all the provided `EventSources`
    ///
    /// - Parameter consumer: The consumer to subscribe.
    /// - Returns: A `CompositeDisposable` which includes the disposables from all the subscriptions
    public func subscribe(consumer: @escaping Consumer<Event>) -> Disposable {
        let disposables = eventSources.map({ (eventSource: AnyEventSource<Event>) -> Disposable in
            eventSource.subscribe(consumer: consumer)
        })

        return CompositeDisposable(disposables: disposables)
    }
}
