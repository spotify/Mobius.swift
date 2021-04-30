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

/// Defines a controller that can be used to start and stop MobiusLoops.
///
/// If a loop is stopped and then started again via the controller, the new loop will continue from where the last one
/// left off.
public final class MobiusController<Model, Event, Effect> {
    typealias Loop = MobiusLoop<Model, Event, Effect>
    typealias LoopConnectable = AsyncDispatchQueueConnectable<Model, Event>

    private struct StoppedState {
        var modelToStartFrom: Model
        var connectables: [UUID: LoopConnectable]
    }

    private struct RunningState {
        var loop: Loop
        var connectables: [UUID: LoopConnectable]
        var disposables: CompositeDisposable
    }

    private typealias State = AsyncStartStopStateMachine<StoppedState, RunningState>

    private let loopFactory: (Model) -> Loop
    private let loopQueue: DispatchQueue
    private let viewQueue: DispatchQueue

    private let state: State

    /// A Boolean indicating whether the MobiusLoop is running or not.
    public var running: Bool {
        return state.running
    }

    /// See `Mobius.Builder.makeController` for documentation
    init(
        builder: Mobius.Builder<Model, Event, Effect>,
        initialModel: Model,
        initiate: Initiate<Model, Effect>? = nil,
        logger: AnyMobiusLogger<Model, Event, Effect>,
        loopQueue loopTargetQueue: DispatchQueue,
        viewQueue: DispatchQueue
    ) {
        /*
         Ownership graph after initing:

                     ┏━━━━━━━━━━━━┓
                ┌────┨ controller ┠────────┬──┐
                │    ┗━━━━━━━━━━┯━┛        │  │
         ┏━━━━━━┷━━━━━━┓    ┏━━━┷━━━━━━━┓  │  │
         ┃ loopFactory ┃    ┃ viewQueue ┃  │  │
         ┗━━━━━━━━━┯━━━┛    ┗━━━━━━━━━━━┛  │  │
              ┏━━━━┷━━━━━━━━━━━━━━━━━━┓    │  │
              ┃ flipEventsToLoopQueue ┃ ┌──┘  │
              ┗━━━━━━━━━━━━━━┯━━━━━━┯━┛ │     │
                             │    ┏━┷━━━┷━┓   │
                             │    ┃ state ┃   │
                             │    ┗━┯━━━━━┛   │
                             │      │ ┌───────┘
                           ┏━┷━━━━━━┷━┷┓
                           ┃ loopQueue ┃
                           ┗━━━━━━━━━━━┛

         In order to construct this bottom-up and fulfill definitive initialization requirements, state and loopQueue are
         duplicated in local variables.
         */

        // The internal loopQueue is a serial queue targeting the provided queue, so that targeting a concurrent queue
        // doesn’t result in concurrent work on the underlying MobiusLoop. This behaviour is documented on
        // `Mobius.Builder.makeController`.
        let loopQueue = DispatchQueue(label: "MobiusController \(Model.self)", target: loopTargetQueue)
        self.loopQueue = loopQueue
        self.viewQueue = viewQueue

        let state = State(
            state: StoppedState(modelToStartFrom: initialModel, connectables: [:]),
            queue: loopQueue
        )
        self.state = state

        // Maps an event consumer to a new event consumer that invokes the original one on the loop queue,
        // asynchronously.
        //
        // The input will be the core `MobiusLoop`’s event dispatcher, which asserts that it isn’t invoked after the
        // loop is disposed. This doesn’t play nicely with asynchrony, so here we assert when the transformed event
        // consumer is invoked, but fail silently if the controller is stopped before the asynchronous block executes.
        func flipEventsToLoopQueue(consumer: @escaping Consumer<Event>) -> Consumer<Event> {
            return { event in
                guard state.running else {
                    MobiusHooks.errorHandler("\(Self.debugTag): cannot accept events when stopped", #file, #line)
                }

                loopQueue.async {
                    guard state.running else {
                        // If we got here, the controller was stopped while this async block was queued. Callers can’t
                        // possibly avoid this except through complete external serialization of all access to the
                        // controller, so it’s not a usage error.
                        //
                        // Note that since we’re on the loop queue at this point, `state` can’t be transitional; it is
                        // necessarily fully running or stopped at this point.
                        return
                    }
                    consumer(event)
                }
            }
        }

        // Wrap initiator (if any) in a logger
        let actualInitiate: Initiate<Model, Effect>
        if let initiate = initiate {
            actualInitiate = logger.wrap(initiate: initiate)
        } else {
            actualInitiate = { First(model: $0) }
        }

        let decoratedBuilder = builder
            .withEventConsumerTransformer(flipEventsToLoopQueue)

        loopFactory = { model in
            let first = actualInitiate(model)
            return decoratedBuilder.start(from: first.model, effects: first.effects)
        }
    }

    deinit {
        if running {
           stop()
        }
    }

    /// Add a `Connectable` to this controller.
    ///
    /// The `Connectable` will be given an event consumer, which it can use to send events to the `MobiusLoop`.
    /// Model updates will be sent to the connection on the provided `DispatchQueue`.
    ///
    /// - Parameter connectable: The `Connectable` to connect upon loop start.
    /// - Parameter acceptQueue: The `DispatchQueue` on which the connection will receive input.
    /// - Returns: A `Disposable` that can be used to remove the `Connectable`.
    /// - Attention: Fails via `MobiusHooks.errorHandler` if the loop is running.
    @discardableResult
    public func connect<LoopConnectable: Connectable>(
        _ connectable: LoopConnectable,
        acceptQueue: DispatchQueue = .main
    ) -> Disposable where LoopConnectable.Input == Model, LoopConnectable.Output == Event {
        do {
            let uuid = UUID()
            try state.mutate { stoppedState in
                stoppedState.connectables[uuid] = AsyncDispatchQueueConnectable(connectable, acceptQueue: acceptQueue)
            }

            return AnonymousDisposable { [weak self] in
                self?.disconnect(uuid: uuid)
            }
        } catch {
           MobiusHooks.errorHandler(
               errorMessage(error, default: "\(Self.debugTag): cannot connect while running"),
               #file,
               #line
           )
       }
    }

    /// Connect a view to this controller.
    ///
    /// May not be called while the loop is running.
    ///
    /// The `Connectable` will be given an event consumer, which the view should use to send events to the `MobiusLoop`.
    /// The view should also return a `Connection` that accepts models and renders them. Disposing the connection should
    /// make the view stop emitting events.
    ///
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop is running or if the controller already is
    ///              connected
    public func connectView<ViewConnectable: Connectable>(
        _ connectable: ViewConnectable
    ) where ViewConnectable.Input == Model, ViewConnectable.Output == Event {
        do {
            let uuid = Self.viewConnectableID
            try state.mutate { stoppedState in
                guard stoppedState.connectables[uuid] == nil else {
                    throw ErrorMessage(message: "\(Self.debugTag): only one view may be connected at a time")
                }

                stoppedState.connectables[uuid] = AsyncDispatchQueueConnectable(connectable, acceptQueue: viewQueue)
            }
        } catch {
           MobiusHooks.errorHandler(
               errorMessage(error, default: "\(Self.debugTag): cannot connect a view while running"),
               #file,
               #line
           )
       }
    }

    /// Disconnect the connected view from this controller.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop is running or if there isn't anything to
    /// disconnect
    public func disconnectView() {
        do {
            let uuid = Self.viewConnectableID
            try state.mutate { stoppedState in
                guard stoppedState.connectables[uuid] != nil else {
                    throw ErrorMessage(message: "\(Self.debugTag): no view connected, cannot disconnect")
                }

                stoppedState.connectables[uuid] = nil
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot disconnect view while running; call stop first"),
                #file,
                #line
            )
        }
    }

    /// Start a MobiusLoop from the current model.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop already is running.
    public func start() {
        do {
            try state.transitionToRunning { stoppedState in
                let loop = loopFactory(stoppedState.modelToStartFrom)
                let disposables: [Disposable] = [loop] + stoppedState.connectables.values.map { connectable in
                    let connection = connectable.connect { [unowned loop] event in
                        // Note: loop.unguardedDispatchEvent will call our flipEventsToLoopQueue, which implements the
                        //       assertion “unguarded” refers to, and also (of course) flips to the loop queue.
                        loop.unguardedDispatchEvent(event)
                    }
                    loop.addObserver(connection.accept)

                    return connection
                }

                return RunningState(
                    loop: loop,
                    connectables: stoppedState.connectables,
                    disposables: CompositeDisposable(disposables: disposables)
                )
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot start a while already running"),
                #file,
                #line
            )
        }
    }

    /// Stop the currently running MobiusLoop.
    ///
    /// When the loop is stopped, the last model of the loop will be remembered and used as the first model the next
    /// time the loop is started.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    /// To stop the loop as an effect, dispatch to a different queue.
    ///
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop isn't running
    public func stop() {
        do {
            try state.transitionToStopped { runningState in
                runningState.disposables.dispose()

                return StoppedState(
                    modelToStartFrom: runningState.loop.latestModel,
                    connectables: runningState.connectables
                )
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot stop a controller while not running"),
                #file,
                #line
            )
        }
    }

    /// Replace which model the controller should start from.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Parameter model: the model with the state the controller should start from
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop is running
    public func replaceModel(_ model: Model) {
        do {
            try state.mutate { stoppedState in
                stoppedState.modelToStartFrom = model
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot replace model while running"),
                #file,
                #line
            )
        }
    }

    /// Get the current model of the loop that this controller is running, or the most recent model if it's not running.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Returns: a model with the state of the controller
    public var model: Model {
        return state.syncRead {
            switch $0 {
            case .stopped(let state):
                return state.modelToStartFrom
            case .running(let state):
                return state.loop.latestModel
            }
        }
    }

    private func disconnect(uuid: UUID) {
        do {
            try state.mutate { stoppedState in
                guard stoppedState.connectables[uuid] != nil else {
                    throw ErrorMessage(message: "\(Self.debugTag): not connected, cannot disconnect")
                }

                stoppedState.connectables[uuid] = nil
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot disconnect while running; call stop first"),
                #file,
                #line
            )
        }
    }

    private static var viewConnectableID: UUID {
        // Reserve 'nil' to prevent collision with generated connection ids
        return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }

    /// Simple error that just carries an error message out of a closure for us
    private struct ErrorMessage: Error {
        let message: String
    }

    /// If `error` is an `ErrorMessage`, return its payload; otherwise, return the provided default message.
    private func errorMessage(_ error: Swift.Error, default defaultMessage: String) -> String {
        if let errorMessage = error as? ErrorMessage {
            return errorMessage.message
        } else {
            return defaultMessage
        }
    }

    private static var debugTag: String {
        return "MobiusController<\(Model.self), \(Event.self), \(Effect.self)>"
    }
}
