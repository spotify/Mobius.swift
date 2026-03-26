// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore

public extension EventSource {
    /// Creates a new `EventSource` which translates events sent by the receiver using a provided translation function,
    /// and forwards them.
    ///
    /// - Parameters:
    ///   - map: Translation function to apply to the forwarded events.
    /// - Returns: An `EventSource` that translates and forwards event from the receiver.
    func map<NewEvent>(transform: @escaping (Event) -> NewEvent) -> AnyEventSource<NewEvent> {
        return AnyEventSource { mappedEventConsumer in
            self.subscribe { originalEvent in
                let mappedEvent = transform(originalEvent)
                mappedEventConsumer(mappedEvent)
            }
        }
    }
}
