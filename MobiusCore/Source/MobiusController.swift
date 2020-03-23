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

/// Defines a controller that can be used to start and stop MobiusLoops.
///
/// If a loop is stopped and then started again via the controller, the new loop will continue from where the last one
/// left off.
public final class MobiusController<Model, Event, Effect> {
    typealias Loop = MobiusLoop<Model, Event, Effect>
    typealias ViewConnectable = AsyncDispatchQueueConnectable<Model, Event>
    typealias ViewConnection = Connection<Model>

    private struct StoppedState {
        var modelToStartFrom: Model
        var viewConnectable: ViewConnectable?

    }

    private struct RunningState {
        var loop: Loop
        var viewConnectable: ViewConnectable?
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

         In order to construct this bottom-up and fulfil definitive initialization requirements, state and loopQueue are
         duplicated in local variables.
         */

        // The internal loopQueue is a serial queue targeting the provided queue, so that targeting a concurrent queue
        // doesn’t result in concurrent work on the underlying MobiusLoop. This behaviour is documented on
        // `Mobius.Builder.makeController`.
        let loopQueue = DispatchQueue(label: "MobiusController \(Model.self)", target: loopTargetQueue)
        self.loopQueue = loopQueue
        self.viewQueue = viewQueue

        let state = State(
            state: StoppedState(modelToStartFrom: initialModel, viewConnectable: nil),
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
                    MobiusHooks.errorHandler("cannot accept events when stopped", #file, #line)
                    return
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

        var decoratedBuilder = builder.withEventConsumerTransformer(flipEventsToLoopQueue)
        if let initiate = initiate {
            decoratedBuilder = decoratedBuilder.withInitiate(initiate)
        }

        loopFactory = { decoratedBuilder.start(from: $0) }
    }

    deinit {
        if running {
           stop()
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
            try state.mutate { stoppedState in
                guard stoppedState.viewConnectable == nil else {
                    throw Error.message("controller only supports connecting one view")
                }

                stoppedState.viewConnectable = AsyncDispatchQueueConnectable(connectable, acceptQueue: viewQueue)
            }
        } catch {
           MobiusHooks.errorHandler(
               errorMessage(error, default: "cannot connect to a running controller"),
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
            try state.mutate { stoppedState in
                guard stoppedState.viewConnectable != nil else {
                    throw Error.message("not connected, cannot disconnect view from controller")
                }

                stoppedState.viewConnectable = nil
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "cannot disconnect from a running controller; call stop first"),
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

                var disposables: [Disposable] = [loop]

                if let viewConnectable = stoppedState.viewConnectable {
                    // Note: loop.unguardedDispatchEvent will call our flipEventsToLoopQueue, which implements the assertion
                    // that “unguarded” refers to, and also (of course) flips to the loop queue.
                    let viewConnection = viewConnectable.connect(loop.unguardedDispatchEvent)
                    loop.addObserver(viewConnection.accept)
                    disposables.append(viewConnection)
                }

                return RunningState(
                    loop: loop,
                    viewConnectable: stoppedState.viewConnectable,
                    disposables: CompositeDisposable(disposables: disposables)
                )
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "cannot start a running controller"),
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
                let model = runningState.loop.latestModel

                runningState.disposables.dispose()

                return StoppedState(modelToStartFrom: model, viewConnectable: runningState.viewConnectable)
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "cannot stop a controller that isn't running"),
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
                errorMessage(error, default: "cannot replace the model of a running loop"),
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

    /// Simple error that just carries an error message out of a closure for us
    private enum Error: Swift.Error {
        case message(String)
    }

    /// If `error` is an `Error.message`, return its payload; otherwise, return the provided default message.
    private func errorMessage(_ error: Swift.Error, default defaultMessage: String) -> String {
        if let myError = error as? Error {
            switch myError {
            case .message(let content):
                return content
            }
        } else {
            return defaultMessage
        }
    }
}
