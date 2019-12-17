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
/// If a loop is stopped and then started again via the controller, the new loop will continue from where the last one left off.
public final class MobiusController<Model, Event, Effect> {
    typealias Loop = MobiusLoop<Model, Event, Effect>
    typealias ViewConnectable = AsyncDispatchQueueConnectable<Model, Event>
    typealias ViewConnection = Connection<Model>

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

        let state = State(model: initialModel, queue: loopQueue)
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
                    MobiusHooks.onError("cannot accept events when stopped")
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

        loopFactory = builder.withEventConsumerTransformer(flipEventsToLoopQueue).start
    }

    /// Connect a view to this controller.
    ///
    /// Must be called before `start`. May not be called directly from the update function or an effect handler running
    /// on the controller’s loop queue.
    ///
    /// The `Connectable` will be given an event consumer, which the view should use to send events to the `MobiusLoop`.
    /// The view should also return a `Connection` that accepts models and renders them. Disposing the connection should
    /// make the view stop emitting events.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running or if the controller already is connected
    public func connectView<C: Connectable>(_ connectable: C) where C.InputType == Model, C.OutputType == Event {
        state.mutateIfStopped(elseError: "cannot connect to a running controller") { state in
            guard state.viewConnectable == nil else {
                MobiusHooks.onError("controller only supports connecting one view")
                return
            }

            state.viewConnectable = AsyncDispatchQueueConnectable(
                connectable,
                acceptQueue: viewQueue
            )
        }
    }

    /// Disconnect UI from this controller.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running or if there isn't anything to disconnect
    public func disconnectView() {
        state.mutateIfStopped(
            elseError: "cannot disconnect from a running controller; call stop first"
        ) { stoppedState in
            guard stoppedState.viewConnectable != nil else {
                MobiusHooks.onError("not connected, cannot disconnect view from controller")
                return
            }

            stoppedState.viewConnectable = nil
        }
    }

    /// Start a MobiusLoop from the current model.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop already is running or no view has been connected
    public func start() {
        state.transitionToRunning(elseError: "cannot start a running controller") { stoppedState in
            guard let viewConnectable = stoppedState.viewConnectable else {
                MobiusHooks.onError("not connected, cannot start controller")
                return nil
            }

            let loop = loopFactory(stoppedState.modelToStartFrom)
            // Note: loop.unguardedDispatchEvent will call our flipEventsToLoopQueue, which implements the assertion
            // that “unguarded” refers to, and also (of course) flips to the loop queue.
            let viewConnection = viewConnectable.connect(loop.unguardedDispatchEvent)
            loop.addObserver(viewConnection.accept)

            return RunningState(loop: loop, viewConnectable: viewConnectable, viewConnection: viewConnection)
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
    /// - Attention: fails via `MobiusHooks.onError` if the loop isn't running
    public func stop() {
        state.transitionToStopped(elseError: "cannot stop a controller that isn't running") { runningState in
            let model = runningState.loop.latestModel

            runningState.loop.dispose()
            runningState.viewConnection.dispose()

            return StoppedState(modelToStartFrom: model, viewConnectable: runningState.viewConnectable)
        }
    }

    /// Replace which model the controller should start from.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Parameter model: the model with the state the controller should start from
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running
    public func replaceModel(_ model: Model) {
        state.mutateIfStopped(elseError: "cannot replace the model of a running loop") { state in
            state.modelToStartFrom = model
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

    // MARK: - State model

    private struct StoppedState {
        var modelToStartFrom: Model
        var viewConnectable: ViewConnectable?

    }

    private struct RunningState {
        var loop: Loop
        var viewConnectable: ViewConnectable
        var viewConnection: ViewConnection
    }

    // State machine representing the two states of a controller, stopped and running.
    // This isn’t an enum because we need synchronized access to the running flag without copying around arbitrarily
    // large models.
    //
    // `running` can safely be read from any thread. Changing `running` and reading or writing state is restricted
    // to the loop queue.
    private final class State {
        // Intermediate states are required to handle the fun, fun case where an event source dispatches an event
        // immediately, which happens before the loop variable is assigned in start(). In this case, we enter
        // flipEventsToLoopQueue() in the .transitioningToRunning state, but the async block cannot proceed until we
        // reach the .running state (because start() is already running on the loop queue).
        private enum RawState {
            case stopped
            case transitioningToRunning
            case running
            case transitioningToStopped
        }

        private let rawState = Synchronized(value: RawState.stopped)
        private let loopQueue: DispatchQueue
        private var stoppedState: StoppedState?
        private var runningState: RunningState?

        enum Snapshot {
            case stopped(StoppedState)
            case running(RunningState)
        }

        init(model: Model, queue: DispatchQueue) {
            stoppedState = StoppedState(modelToStartFrom: model, viewConnectable: nil)
            loopQueue = queue
        }

        /// Test whether we’re in a running state. Ongoing transitions are considered running states.
        ///
        /// This is safe to invoke from any queue, including the loop queue.
        var running: Bool {
            switch rawState.value {
            case .stopped:
                return false
            case .transitioningToRunning, .running, .transitioningToStopped:
                return true
            }
        }

        /// Call `closure` with the current state. It will execute on the loop queue.
        func syncRead<T>(_ closure: (Snapshot) throws -> T) rethrows -> T {
            dispatchPrecondition(condition: .notOnQueue(loopQueue))
            return try loopQueue.sync {
                try closure(snapshot())
            }
        }

        /// Mutate the stopped state, assuming we’re currently stopped. If not, fail with the provided error message.
        func mutateIfStopped(elseError error: String, _ closure: (inout StoppedState) -> Void) {
            dispatchPrecondition(condition: .notOnQueue(loopQueue))
            loopQueue.sync {
                switch snapshot() {
                case .running:
                    MobiusHooks.onError(error)
                case .stopped(var state):
                    closure(&state)
                    stoppedState = state
                }
            }
        }

        /// Transition from a stopped state to a running state, assuming we’re currently stopped. If not, fail with the
        /// provided error message.
        ///
        /// The `transition` closure may return nil to indicate failure, in which case the state remains unchanged. This
        /// behaviour isn’t desired but is forced by our error hooking mechanism – if `transition` calls
        /// `MobiusHooks.onError` it should then return `nil`.
        func transitionToRunning(elseError error: String, _ transition: (StoppedState) -> RunningState?) {
            dispatchPrecondition(condition: .notOnQueue(loopQueue))
            loopQueue.sync {
                switch snapshot() {
                case .running:
                    MobiusHooks.onError(error)
                case .stopped(let stoppedState):
                    rawState.value = .transitioningToRunning
                    if let runningState = transition(stoppedState) {
                        become(running: runningState)
                    } else {
                        rawState.value = .stopped
                    }
                }
            }
        }

        /// Transition from a running state to a stopped state, assuming we’re currently running. If not, fail with the
        /// provided error message.
        ///
        /// The `transition` closure may return nil to indicate failure, in which case the state remains unchanged. This
        /// behaviour isn’t desired but is forced by our error hooking mechanism – if `transition` calls
        /// `MobiusHooks.onError` it should then return `nil`.
        func transitionToStopped(elseError error: String, _ transition: (RunningState) -> StoppedState?) {
            dispatchPrecondition(condition: .notOnQueue(loopQueue))
            loopQueue.sync {
                switch snapshot() {
                case .stopped:
                    MobiusHooks.onError(error)
                case .running(let runningState):
                    rawState.value = .transitioningToStopped
                    if let stoppedState = transition(runningState) {
                        become(stopped: stoppedState)
                    } else {
                        rawState.value = .running
                    }
                }
            }
        }

        /// Generate a `Snapshot`  reflecting the current, er, state of the `State`.
        ///
        /// This function is the only point where we deal with the two optionals.
        private func snapshot() -> Snapshot {
            dispatchPrecondition(condition: .onQueue(loopQueue))

            if running {
                guard let runningState = runningState else { preconditionFailure("Internal invariant broken") }
                return .running(runningState)
            } else {
                guard let stoppedState = stoppedState else { preconditionFailure("Internal invariant broken") }
                return .stopped(stoppedState)
            }
        }

        private func become(running state: RunningState) {
            dispatchPrecondition(condition: .onQueue(loopQueue))

            self.runningState = state
            rawState.value = .running
            self.stoppedState = nil
        }

        private func become(stopped state: StoppedState) {
            dispatchPrecondition(condition: .onQueue(loopQueue))

            self.stoppedState = state
            rawState.value = .stopped
            self.runningState = nil
        }
    }
}
