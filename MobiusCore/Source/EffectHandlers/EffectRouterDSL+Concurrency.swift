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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension _PartialEffectRouter where EffectParameters: Sendable {
    /// Routes the `Effect` to an asynchronous closure.
    ///
    /// - Parameter handler: An asynchronous closure receiving the `Effect`'s parameters as input.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable (EffectParameters) async -> Void) -> EffectRouter<Effect, Event> {
        to { parameters, _ in
            await handler(parameters)
        }
    }

    /// Routes the `Effect` to an asynchronous throwing closure.
    ///
    /// - Parameter handler: An asynchronous throwing closure receiving the `Effect`'s parameters as input.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable (EffectParameters) async throws -> Void) -> EffectRouter<Effect, Event> {
        to { parameters, _ in
            try await handler(parameters)
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension _PartialEffectRouter where EffectParameters == Void {
    /// Routes the `Effect` to an asynchronous closure.
    ///
    /// - Parameter handler: An asynchronous closure.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable () async -> Void) -> EffectRouter<Effect, Event> {
        to { _, _ in
            await handler()
        }
    }

    /// Routes the `Effect` to an asynchronous throwing closure.
    ///
    /// - Parameter handler: An asynchronous throwing closure.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable () async throws -> Void) -> EffectRouter<Effect, Event> {
        to { _, _ in
            try await handler()
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension _PartialEffectRouter where EffectParameters: Sendable {
    /// Routes the `Effect` to an asynchronous closure producing a single `Event`.
    ///
    /// - Parameter handler: An asynchronous closure receiving the `Effect`'s parameters as input and producing a single `Event` as output.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable (EffectParameters) async -> Event) -> EffectRouter<Effect, Event> {
        to { parameters, callback in
            await callback(handler(parameters))
        }
    }

    /// Routes the `Effect` to an asynchronous throwing closure producing a single `Event`.
    ///
    /// - Parameter handler: An asynchronous throwing closure receiving the `Effect`'s parameters as input and producing a single `Event` as output.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable (EffectParameters) async throws -> Event) -> EffectRouter<Effect, Event> {
        to { parameters, callback in
            try await callback(handler(parameters))
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension _PartialEffectRouter where EffectParameters == Void {
    /// Routes the `Effect` to an asynchronous closure producing a single `Event`.
    ///
    /// - Parameter handler: An asynchronous closure producing a single `Event` as output.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable () async -> Event) -> EffectRouter<Effect, Event> {
        to { _, callback in
            await callback(handler())
        }
    }

    /// Routes the `Effect` to an asynchronous throwing closure producing a single `Event`.
    ///
    /// - Parameter handler: An asynchronous throwing closure producing a single `Event` as output.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to(_ handler: @escaping @Sendable () async throws -> Event) -> EffectRouter<Effect, Event> {
        to { _, callback in
            try await callback(handler())
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension _PartialEffectRouter where EffectParameters: Sendable {
    /// Routes the `Effect` to an asynchronous closure producing a sequence of `Event`s.
    ///
    /// - Parameter handler: An asynchronous closure receiving the `Effect`'s parameters as input and producing an `AsyncSequence` of `Event`s as output.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to<S: AsyncSequence>(
        _ handler: @escaping @Sendable (EffectParameters) async -> S
    ) -> EffectRouter<Effect, Event> where S.Element == Event {
        to { parameters, callback in
            for try await output in await handler(parameters) {
                callback(output)
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension _PartialEffectRouter where EffectParameters == Void {
    /// Routes the `Effect` to an asynchronous closure producing a sequence of `Event`s.
    ///
    /// - Parameter handler: An asynchronous closure producing an `AsyncSequence` of `Event`s as output.
    /// - Returns: An `EffectRouter` that includes a handler for the given `Effect`.
    func to<S: AsyncSequence>(
        _ handler: @escaping @Sendable () async -> S
    ) -> EffectRouter<Effect, Event> where S.Element == Event {
        to { _, callback in
            for try await output in await handler() {
                callback(output)
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private extension _PartialEffectRouter where EffectParameters: Sendable {
    private struct UncheckedSendable<Value>: @unchecked Sendable {
        let wrappedValue: Value
    }

    func to(
        _ handler: @escaping @Sendable (EffectParameters, Consumer<Event>) async -> Void
    ) -> EffectRouter<Effect, Event> {
        to { parameters, callback in
            let sendableCallback = UncheckedSendable(wrappedValue: callback)

            let task = Task {
                defer { sendableCallback.wrappedValue.end() }
                await handler(parameters, sendableCallback.wrappedValue.send)
            }

            return AnonymousDisposable {
                task.cancel()
            }
        }
    }

    func to(
        _ handler: @escaping @Sendable (EffectParameters, Consumer<Event>) async throws -> Void
    ) -> EffectRouter<Effect, Event> {
        to { parameters, callback in
            let sendableCallback = UncheckedSendable(wrappedValue: callback)

            let task = Task {
                defer { sendableCallback.wrappedValue.end() }
                try await handler(parameters, sendableCallback.wrappedValue.send)
            }

            return AnonymousDisposable {
                task.cancel()
            }
        }
    }
}
