// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Protocol for event sources.
///
/// The event source is used for subscribing to events that are external to the Mobius
/// application. This is primarily meant to be used for environmental events - events that come from
/// external signals, like change of network connectivity or a periodic timer, rather than happening
/// because of an effect being triggered or the UI being interacted with.
public protocol EventSource: AnyObject {
    associatedtype Event

    /// Subscribes the supplied consumer to the events from this event source, until the returned
    /// `Disposable` is disposed. Multiple such subscriptions can be in place concurrently for a
    /// given event source, without affecting each other.
    ///
    /// - Parameter eventConsumer: the consumer that should receive events from the source.
    /// - Returns: a `Disposable` used to stop the source from emitting any more events to this consumer.
    func subscribe(consumer: @escaping Consumer<Event>) -> Disposable
}
