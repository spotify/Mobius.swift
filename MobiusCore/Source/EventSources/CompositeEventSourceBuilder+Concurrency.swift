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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension CompositeEventSourceBuilder where Event: Sendable {
    /// Returns a new `CompositeEventSourceBuilder` with the specified `AsyncSequence` added to it.
    ///
    /// - Note: The `consumerQueue` parameter is intended to be used when building a `MobiusLoop`.
    /// It can safely be omitted when building a `MobiusController`, which automatically handles sending events to the loop queue.
    ///
    /// - Parameter sequence: An `AsyncSequence` producing `Event`s.
    /// - Parameter consumerQueue: An optional callback queue to consume events on.
    /// - Returns: A `CompositeEventSourceBuilder` that includes the given event source.
    func addEventSource<Sequence: AsyncSequence & Sendable>(
        _ sequence: Sequence,
        receiveOn consumerQueue: DispatchQueue? = nil
    ) -> CompositeEventSourceBuilder<Event> where Sequence.Element == Event {
        addEventSource(AsyncSequenceEventSource(sequence: sequence, consumerQueue: consumerQueue))
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private final class AsyncSequenceEventSource<Sequence: AsyncSequence & Sendable>: EventSource where Sequence.Element: Sendable {
    private struct SendableConsumer<Output>: @unchecked Sendable {
        let wrappedValue: Consumer<Output>
    }

    private let sequence: Sequence
    private let consumerQueue: DispatchQueue?

    init(sequence: Sequence, consumerQueue: DispatchQueue? = nil) {
        self.sequence = sequence
        self.consumerQueue = consumerQueue
    }

    func subscribe(consumer: @escaping Consumer<Sequence.Element>) -> Disposable {
        // Prevents sending events after dispose by wrapping the consumer to enforce synchronous access.
        let sendableConsumer = SendableConsumer(wrappedValue: consumer)
        let protectedConsumer = Synchronized<SendableConsumer<Sequence.Element>?>(value: sendableConsumer)
        let threadSafeConsumer: @Sendable (Sequence.Element) -> Void = { event in
            protectedConsumer.read { consumer in consumer?.wrappedValue(event) }
        }

        let task = Task { [sequence, consumerQueue] in
            for try await event in sequence {
                if let consumerQueue {
                    consumerQueue.async { threadSafeConsumer(event) }
                } else {
                    threadSafeConsumer(event)
                }
            }
        }

        return AnonymousDisposable {
            protectedConsumer.value = nil
            task.cancel()
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Synchronized: @unchecked Sendable where Value: Sendable {}
