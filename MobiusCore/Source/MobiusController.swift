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
/// If a loop is stopped and then started again, the new loop will continue from where the last one left off.
public final class MobiusController<Model, Event, Effect> {
    private let loopFactory: (Model) -> MobiusLoop<Model, Event, Effect>

    private var viewConnectable: AsyncDispatchQueueConnectable<Model, Event>?
    private var viewConnection: Connection<Model>?
    private var loop: MobiusLoop<Model, Event, Effect>?
    private var modelToStartFrom: Model
    private let loopQueue: DispatchQueue
    private let viewQueue: DispatchQueue

    /// A Boolean indicating whether the MobiusLoop is running or not.
    ///
    /// May not be called directly from the update function or an effect handler running on the controller’s loop queue.
    public var running: Bool {
        return synchronized {
            loop != nil
        }
    }

    init(
        builder: Mobius.Builder<Model, Event, Effect>,
        initialModel: Model,
        loopQueue: DispatchQueue,
        viewQueue: DispatchQueue
    ) {
        let actualLoopQueue = DispatchQueue(label: "MobiusController \(Model.self)", target: loopQueue)
        modelToStartFrom = initialModel
        self.loopQueue = actualLoopQueue
        self.viewQueue = viewQueue

        var running: () -> Bool = { false }

        func flipEventsToLoopQueue(consumer: @escaping Consumer<Event>) -> Consumer<Event> {
            return { event in
                guard running() else {
                    MobiusHooks.onError("cannot accept events when stopped")
                    return
                }

                actualLoopQueue.async {
                    guard running() else {
                        // If we got here, the controller was stopped while this async block was queued. Callers can’t
                        // possibly avoid this except through complete external serialization of all access to the
                        // controller, so it’s not a usage error.
                        return
                    }
                    consumer(event)
                }
            }
        }

        loopFactory = builder.withEventConsumerTransformer(flipEventsToLoopQueue).start

        // NOTE: This is fragile, or at least scary. We call `running` twice, and the first one isn’t necessarily on
        // the loop queue. This “seems to work” when we use a weak to self reference here, because it adds a fence. If
        // we use unowned or strong references, we crash in unit tests.
        //
        // I want to fix this by refactoring state representation in the loop controller, but I think it would be easier
        // to review that as a separate PR.
        running = { [weak self] in self?.loop != nil }
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
        synchronized {
            guard viewConnectable == nil else {
                MobiusHooks.onError("controller only supports connecting one view")
                return
            }

            viewConnectable = AsyncDispatchQueueConnectable(connectable, acceptQueue: viewQueue)
        }
    }

    /// Disconnect UI from this controller.
    ///
    /// May not be called directly from the update function or an effect handler running on the controller’s loop queue.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running or if there isn't anything to disconnect
    public func disconnectView() {
        synchronized {
            guard loop == nil else {
                MobiusHooks.onError("cannot disconnect from a running controller; invoke stop first")
                return
            }
            guard viewConnectable != nil else {
                MobiusHooks.onError("not connected, cannot disconnect view from controller")
                return
            }

            viewConnectable = nil
        }
    }

    /// Start a MobiusLoop from the current model.
    ///
    /// May not be called directly from the update function or an effect handler running on the controller’s loop queue.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop already is running or no view has been connected
    public func start() {
        synchronized {
            guard let viewConnectable = viewConnectable else {
                MobiusHooks.onError("not connected, cannot start controller")
                return
            }
            guard loop == nil else {
                MobiusHooks.onError("cannot start a running controller")
                return
            }

            let loop = loopFactory(self.modelToStartFrom)
            self.loop = loop

            let viewConnection = viewConnectable.connect(loop.dispatchEvent)
            self.viewConnection = viewConnection

            loop.addObserver(viewConnection.accept)
        }
    }

    /// Stop the currently running MobiusLoop.
    ///
    /// When the loop is stopped, the last model of the loop will be remembered and used as the first model the next
    /// time the loop is started.
    ///
    /// May not be called directly from the update function or an effect handler running on the controller’s loop queue.
    /// To stop the queue as an effect, dispatch to a different queue.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop isn't running
    public func stop() {
        synchronized {
            guard let loop = loop else {
                MobiusHooks.onError("cannot stop a controller that isn't running")
                return
            }

            modelToStartFrom = loop.latestModel

            loop.dispose()
            viewConnection?.dispose()

            self.loop = nil
        }
    }

    /// Replace which model the controller should start from.
    ///
    /// May not be called directly from the update function or an effect handler running on the controller’s loop queue.
    ///
    /// - Parameter model: the model with the state the controller should start from
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running
    public func replaceModel(_ model: Model) {
        synchronized {
            guard loop == nil else {
                MobiusHooks.onError("cannot replace the model of a running loop")
                return
            }

            modelToStartFrom = model
        }
    }

    /// Get the current model of the loop that this controller is running, or the most recent model if it's not running.
    ///
    /// May not be called directly from the update function or an effect handler running on the controller’s loop queue.
    ///
    /// - Returns: a model with the state of the controller
    public var model: Model {
        return synchronized {
            loop?.latestModel ?? modelToStartFrom
        }
    }

    private func synchronized<Result>(closure: () -> Result) -> Result {
        dispatchPrecondition(condition: .notOnQueue(loopQueue))
        return loopQueue.sync(execute: closure)
    }
}
