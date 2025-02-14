// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Defines a controller that can be used to start and stop MobiusLoops.
///
/// If a loop is stopped and then started again via the controller, the new loop will continue from where the last one
/// left off.
public final class MobiusController<Model, Event, Effect> {
    typealias Loop = MobiusLoop<Model, Event, Effect>
    typealias ViewConnectable = AsyncDispatchQueueConnectable<Model, Event>

    private struct StoppedState {
        var modelToStartFrom: Model
        var viewConnectables: [UUID: ViewConnectable]
    }

    private struct RunningState {
        var loop: Loop
        var viewConnectables: [UUID: ViewConnectable]
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
            state: StoppedState(modelToStartFrom: initialModel, viewConnectables: [:]),
            queue: loopQueue
        )
        self.state = state

        // Maps an event consumer to a new event consumer that asynchronously invokes the original on the loop queue.
        //
        // The input will be the core `MobiusLoop`’s event dispatcher, which asserts that it isn’t invoked after the
        // loop is disposed. This doesn’t play nicely with asynchrony, so here we fail silently if the controller is
        // stopped before the asynchronous block executes.
        func flipEventsToLoopQueue(consumer: @escaping Consumer<Event>) -> Consumer<Event> {
            return { event in
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

    /// Connect a view to this controller.
    ///
    /// The `Connectable` will be given an event consumer, which the view should use to send events to the `MobiusLoop`.
    /// The view should also return a `Connection` that accepts models and renders them. Disposing the connection should
    /// make the view stop emitting events.
    ///
    /// - Parameter connectable: the view to connect
    /// - Returns: an identifier that can be used to disconnect the view
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop is running
    @discardableResult
    public func connectView<ViewConnectable: Connectable>(
        _ connectable: ViewConnectable
    ) -> UUID where ViewConnectable.Input == Model, ViewConnectable.Output == Event {
        do {
            let id = UUID()
            try state.mutate { stoppedState in
                stoppedState.viewConnectables[id] = AsyncDispatchQueueConnectable(connectable, acceptQueue: viewQueue)
            }

            return id
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
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop is running, if there is more than 1 connection,
    /// or if there isn't anything to disconnect
    public func disconnectView() {
        do {
            try state.mutate { stoppedState in
                guard stoppedState.viewConnectables.count <= 1 else {
                    throw ErrorMessage(message: "\(Self.debugTag): missing view connection id, cannot disconnect")
                }

                guard let id = stoppedState.viewConnectables.keys.first else {
                    throw ErrorMessage(message: "\(Self.debugTag): no view connected, cannot disconnect")
                }

                stoppedState.viewConnectables[id] = nil
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot disconnect view while running; call stop first"),
                #file,
                #line
            )
        }
    }

    /// Disconnect a connected view from this controller.
    ///
    /// May not be called directly from an effect handler running on the controller’s loop queue.
    ///
    /// - Parameter id: the identifier received from calling `connectView(_:)`
    /// - Attention: fails via `MobiusHooks.errorHandler` if the loop is running or if the id is not connected
    public func disconnectView(id: UUID) {
        do {
            try state.mutate { stoppedState in
                guard stoppedState.viewConnectables[id] != nil else {
                    throw ErrorMessage(message: "\(Self.debugTag): invalid view connection, cannot disconnect")
                }

                stoppedState.viewConnectables[id] = nil
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
                let disposables: [Disposable] = [loop] + stoppedState.viewConnectables.values.map { connectable in
                    let connection = connectable.connect { [weak loop] event in
                        guard let loop = loop else {
                            // This failure should not be reached under normal circumstances because it is handled by
                            // AsyncDispatchQueueConnectable. Stopping here means that the viewConnectable called its
                            // consumer reference after stop() has disposed the connection and deallocated the loop.
                            MobiusHooks.errorHandler("\(Self.debugTag): cannot use invalid consumer", #file, #line)
                        }

                        loop.unguardedDispatchEvent(event)
                    }
                    loop.addObserver(connection.accept)

                    return connection
                }

                return RunningState(
                    loop: loop,
                    viewConnectables: stoppedState.viewConnectables,
                    disposables: CompositeDisposable(disposables: disposables)
                )
            }
        } catch {
            MobiusHooks.errorHandler(
                errorMessage(error, default: "\(Self.debugTag): cannot start a controller while already running"),
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
                    viewConnectables: runningState.viewConnectables
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
