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
public final class MobiusLoop<Types: LoopTypes>: Disposable, CustomDebugStringConvertible {
    private let eventProcessor: EventProcessor<Types>
    private let modelPublisher: ConnectablePublisher<Types.Model>
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
        eventProcessor: EventProcessor<Types>,
        modelPublisher: ConnectablePublisher<Types.Model>,
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
    public func addObserver(_ consumer: @escaping Consumer<Types.Model>) -> Disposable {
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

    public var latestModel: Types.Model {
        return eventProcessor.latestModel
    }

    public func dispatchEvent(_ event: Types.Event) {
        guard !disposed.value else {
            // Callers are responsible for ensuring dispatchEvent is never entered after dispose.
            MobiusHooks.onError("event submitted after dispose")
            return
        }

        eventProcessor.accept(event)
    }

    // swiftlint:disable:next function_parameter_count
    static func createLoop<C: Connectable>(
        update: @escaping Update<Types>,
        effectHandler: C,
        initialModel: Types.Model,
        initiator: @escaping Initiator<Types>,
        eventSource: AnyEventSource<Types.Event>,
        eventQueue: DispatchQueue,
        effectQueue: DispatchQueue,
        logger: AnyMobiusLogger<Types>
    ) -> MobiusLoop<Types> where C.InputType == Types.Effect, C.OutputType == Types.Event {
        let loggingInitiator = LoggingInitiator<Types>(initiator, logger)
        let loggingUpdate = LoggingUpdate<Types>(update, logger)

        // create somewhere for the event processor to push nexts to; later, we'll observe these nexts and
        // dispatch models and effects to the right places
        let nextPublisher = ConnectablePublisher<Next<Types.Model, Types.Effect>>()

        // event processor: process events, publish Next:s, retain current model
        let eventProcessor = EventProcessor<Types>(update: loggingUpdate.update, publisher: nextPublisher, queue: eventQueue)

        // effect handler: handle effects, push events to the event processor
        let effectHandlerConnection = effectHandler.connect(eventProcessor.accept)

        let eventSourceDisposable = eventSource.subscribe(consumer: eventProcessor.accept)

        // model observer support
        let modelPublisher = ConnectablePublisher<Types.Model>()

        // ensure model updates get published and effects dispatched to the effect handler
        let nextConsumer: Consumer<Next<Types.Model, Types.Effect>> = { (next: Next<Types.Model, Types.Effect>) in
            if let model = next.model {
                modelPublisher.post(model)
            }

            next.effects.forEach({ (effect: Types.Effect) in
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
