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

import Foundation

/// A `MobiusLoop` is the core encapsulation of business logic in Mobius.
///
/// It stores a current model, applies incoming events, processes the resulting effects, and broadcasts model changes
/// to observers.
///
/// Use `Mobius.loop(update:effectHandler:)` to create an instance.
public final class MobiusLoop<Model, Event, Effect>: Disposable {
    private let access = ConcurrentAccessDetector()
    private var workBag: WorkBag

    private var effectConnection: Connection<Effect>! = nil
    private var consumeEvent: Consumer<Event>! = nil
    private let modelPublisher: ConnectablePublisher<Model>

    private var model: Model

    private var disposable: CompositeDisposable?

    init(
        model: Model,
        update: Update<Model, Event, Effect>,
        eventSource: AnyEventSource<Event>,
        eventConsumerTransformer: ConsumerTransformer<Event>,
        effectHandler: AnyConnectable<Effect, Event>,
        effects: [Effect],
        logger: AnyMobiusLogger<Model, Event, Effect>
    ) {
        let loggingUpdate = logger.wrap(update: update.updateClosure)

        let workBag = WorkBag(accessGuard: access)
        self.workBag = workBag

        self.model = model
        self.modelPublisher = ConnectablePublisher<Model>(accessGuard: access)

        // consumeEvent is the closure that processes an event and handles the model and effect updates. It needs to
        // be a closure so that it can be transformed by eventConsumerTransformer, and to handle ownership correctly:
        // consumeEvent holds on to the update function and workbag, and also holds self while its work bag submission
        // is queued.
        //
        // Originally the processNext(...) invocation was wrapped in a method, but that just spread things out more.
        let consumeEvent = eventConsumerTransformer { [unowned self] event in
            // Note: captures self strongly until the block is serviced by the workBag
            let processNext = self.processNext
            workBag.submit {
                // Note: we must read self.model inside the submit block, since other queued blocks may have executed
                // between submitting and getting here.
                // This is an unowned read of `self`, but at this point `self` is being kept alive by the local
                // `processNext`.
                let model = self.model
                processNext(loggingUpdate(model, event))
            }
            workBag.service()
        }
        self.consumeEvent = consumeEvent

        // These must be set up after consumeEvent, which refers to self; that’s why they need to be IUOs.
        self.effectConnection = effectHandler.connect(consumeEvent)
        let eventSourceDisposable = eventSource.subscribe(consumer: consumeEvent)

        self.disposable = CompositeDisposable(disposables: [
            effectConnection,
            modelPublisher,
            eventSourceDisposable,
        ])

        // Prime the modelPublisher, and queue up any initial effects.
        processNext(.next(model, effects: effects))

        // When we’re fully initialized, we can process any initial effects plus events that may have been queued up
        // by the effect handler or event source when we connected to them.
        workBag.start()
    }

    deinit {
        dispose()
    }

    /// Add an observer of model changes to this loop. If `getMostRecentModel()` is non-nil,
    /// the observer will immediately be notified of the most recent model. The observer will be
    /// notified of future changes to the model until the loop or the returned `Disposable` is
    /// disposed.
    ///
    /// - Parameter consumer: an observer of model changes
    /// - Returns: a `Disposable` that can be used to stop further notifications to the observer
    @discardableResult
    public func addObserver(_ consumer: @escaping Consumer<Model>) -> Disposable {
        return access.guard {
            modelPublisher.connect(to: consumer)
        }
    }

    public func dispose() {
        access.guard {
            let disposable = self.disposable
            self.disposable = nil
            disposable?.dispose()
        }
    }

    /// Extract the latest model from the loop.
    ///
    /// This property is discouraged; in general, it is preferable to add an observer with `addObserver`.
    public var latestModel: Model {
        return access.guard { model }
    }

    /// Send an event to the loop.
    ///
    /// - Parameter event: The event to dispatch.
    public func dispatchEvent(_ event: Event) {
        return access.guard {
            guard !disposed else {
                // Callers are responsible for ensuring dispatchEvent is never entered after dispose.
                MobiusHooks.errorHandler("\(debugTag): event submitted after dispose", #file, #line)
            }

            unguardedDispatchEvent(event)
        }
    }

    /// Like `dispatchEvent`, but without asserting that the loop hasn’t been disposed.
    ///
    /// This should not be used directly, but is useful in constructing asynchronous wrappers around loops (like
    /// `MobiusController`, where the `eventConsumerTransformer` is used to implement equivalent async-safe assertions).
    public func unguardedDispatchEvent(_ event: Event) {
        consumeEvent(event)
    }

    // MARK: - Implementation details

    /// Apply a `Next`:
    ///
    /// * Store the new model, if any, in self.model
    /// * Post the new model, if any, to observers
    /// * Queue up any effects in the workBag
    /// * Service the workBag
    private func processNext(_ next: Next<Model, Effect>) {
        if let newModel = next.model {
            model = newModel
            modelPublisher.post(model)
        }

        for effect in next.effects {
            workBag.submit {
                self.effectConnection.accept(effect)
            }
        }
        workBag.service()
    }

    /// Test whether the loop has been disposed.
    private var disposed: Bool {
        return disposable == nil
    }

    /// A string to identify the MobiusLoop; currently the type name including type arguments.
    fileprivate var debugTag: String {
        return "\(type(of: self))"
    }
}

extension MobiusLoop: CustomDebugStringConvertible {
    public var debugDescription: String {
        return access.guard {
            if disposed {
                return "disposed \(debugTag)!"
            }

            return "\(debugTag){ \(String(reflecting: model)) }"
        }
    }
}
