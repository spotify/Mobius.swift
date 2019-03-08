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

/// - Callout(Instantiating): Use `Mobius.loop(update:effectHandler:)` to create an instance.
public final class MobiusLoop<T: LoopTypes>: Disposable, CustomDebugStringConvertible {
    private let eventProcessor: EventProcessor<T>
    private let modelPublisher: ConnectablePublisher<T.Model>
    private let disposable: Disposable

    // AtomicBool is used here to ensure coherence in the event that dispose and dispatchEvent are
    // called on different threads.
    private var disposed = AtomicBool(false)

    public var debugDescription: String {
        if disposed.value {
            return "disposed loop!"
        }
        return "\(type(of: self)) \(eventProcessor)"
    }

    init(
        eventProcessor: EventProcessor<T>,
        modelPublisher: ConnectablePublisher<T.Model>,
        disposable: Disposable
    ) {
        self.eventProcessor = eventProcessor
        self.modelPublisher = modelPublisher
        self.disposable = disposable
    }

    /// Add an observer of model changes to this loop. If `getMostRecentModel()` is non-nil,
    /// the observer will immediately be notified of the most recent model. The observer will be
    /// notified of future changes to the model until the loop or the returned `Disposable` is
    /// disposed.

    /// - Parameter consumer: an observer of model changes
    /// - Returns: a `Disposable` that can be used to stop further notifications to the observer
    @discardableResult
    public func addObserver(_ consumer: @escaping Consumer<T.Model>) -> Disposable {
        return modelPublisher.connect(to: consumer)
    }

    public func dispose() {
        let alreadyDisposed = disposed.getAndSet(value: true)

        if !alreadyDisposed {
            modelPublisher.dispose()
            eventProcessor.dispose()
            disposable.dispose()
        }
    }

    deinit {
        dispose()
    }

    public func getMostRecentModel() -> T.Model? {
        return eventProcessor.readCurrentModel()
    }

    public func dispatchEvent(_ event: T.Event) {
        guard !disposed.value else {
            // Callers are responsible for ensuring dispatchEvent is never entered after dispose.
            MobiusHooks.onError("event submitted after dispose")
            return
        }

        eventProcessor.accept(event)
    }

    // swiftlint:disable:next function_parameter_count
    static func createLoop<C: Connectable>(
        update: @escaping Update<T>,
        effectHandler: C,
        initialModel: T.Model,
        initiator: @escaping Initiator<T>,
        eventSource: AnyEventSource<T.Event>,
        eventQueue: DispatchQueue,
        effectQueue: DispatchQueue,
        logger: AnyMobiusLogger<T>
    ) -> MobiusLoop<T> where C.InputType == T.Effect, C.OutputType == T.Event {
        let loggingInitiator = LoggingInitiator<T>(initiator, logger)
        let loggingUpdate = LoggingUpdate<T>(update, logger)

        // create somewhere for the event processor to push nexts to; later, we'll observe these nexts and
        // dispatch models and effects to the right places
        let nextPublisher = ConnectablePublisher<Next<T.Model, T.Effect>>()

        // event processor: process events, publish Next:s, retain current model
        let eventProcessor = EventProcessor<T>(update: loggingUpdate.update, publisher: nextPublisher, queue: eventQueue)

        // effect handler: handle effects, push events to the event processor
        let effectHandlerConnection = effectHandler.connect(eventProcessor.accept)

        let eventSourceDisposable = eventSource.subscribe(consumer: eventProcessor.accept)

        // model observer support
        let modelPublisher = ConnectablePublisher<T.Model>()

        // ensure model updates get published and effects dispatched to the effect handler
        let nextConsumer: Consumer<Next<T.Model, T.Effect>> = { (next: Next<T.Model, T.Effect>) in
            if let model = next.model {
                modelPublisher.post(model)
            }

            next.effects.forEach({ (effect: T.Effect) in
                effectQueue.async {
                    effectHandlerConnection.accept(effect)
                }
            })
        }
        let nextConnection = nextPublisher.connect(to: nextConsumer)

        // everything is hooked up, start processing!
        eventProcessor.start(from: loggingInitiator.initiate(initialModel))

        return MobiusLoop(
            eventProcessor: eventProcessor,
            modelPublisher: modelPublisher,
            disposable: CompositeDisposable(disposables: [eventSourceDisposable, nextConnection, effectHandlerConnection])
        )
    }
}
