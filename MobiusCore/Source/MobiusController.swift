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
/// If a loop is stopped and then started again, the new loop will continue from where the last
/// one left off.
public class MobiusController<T: LoopTypes> {
    private let loopFactory: (T.Model) -> MobiusLoop<T>
    private let lock = NSRecursiveLock()

    private var viewConnectable: ConnectClosure<T.Model, T.Event>?
    private var viewConnection: Connection<T.Model>?
    private var loop: MobiusLoop<T>?
    private var modelToStartFrom: T.Model

    /// A Boolean indicating whether the MobiusLoop is running or not.
    public var isRunning: Bool {
        return lock.synchronized {
            loop != nil
        }
    }

    public init(builder: Mobius.Builder<T>, defaultModel: T.Model) {
        loopFactory = builder.start
        modelToStartFrom = defaultModel
    }

    /// Connect a view to this controller.
    ///
    /// Must be called before `start`.
    ///
    /// The `Connectable` will be given an event consumer, which the view should use to send
    /// events to the `MobiusLoop`. The view should also return a `Connection` that accepts
    /// models and renders them. Disposing the connection should make the view stop emitting events.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running or if the controller already is connected
    public func connectView<C: Connectable>(_ connectable: C) where C.InputType == T.Model, C.OutputType == T.Event {
        lock.synchronized {
            guard viewConnectable == nil else {
                MobiusHooks.onError("controller only supports connecting one view")
                return
            }

            self.viewConnectable = connectable.connect
        }
    }

    /// Disconnect UI from this controller.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running or if there isn't anything to disconnect
    public func disconnectView() {
        lock.synchronized {
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
    /// - Attention: fails via `MobiusHooks.onError` if the loop already is running or no view has been connected
    public func start() {
        lock.synchronized {
            guard let viewConnectable = self.viewConnectable else {
                MobiusHooks.onError("not connected, cannot start controller")
                return
            }
            guard loop == nil else {
                MobiusHooks.onError("cannot start a running controller")
                return
            }

            loop = loopFactory(modelToStartFrom)

            let viewConnection = viewConnectable(loop!.dispatchEvent)
            self.viewConnection = viewConnection
            loop!.addObserver(viewConnection.accept)
        }
    }

    /// Stop the currently running MobiusLoop.
    ///
    /// When the loop is stopped, the last model of the loop will be remembered and used as the
    /// first model the next time the loop is started.
    ///
    /// - Attention: fails via `MobiusHooks.onError` if the loop isn't running
    public func stop() {
        lock.synchronized {
            guard loop != nil else {
                MobiusHooks.onError("cannot stop a controller that isn't running")
                return
            }

            modelToStartFrom = loop!.getMostRecentModel() ?? modelToStartFrom

            loop!.dispose()
            viewConnection?.dispose()

            loop = nil
        }
    }

    /// Replace which model the controller should start from.
    ///
    /// - Parameter model: the model with the state the controller should start from
    /// - Attention: fails via `MobiusHooks.onError` if the loop is running
    public func replaceModel(_ model: T.Model) {
        lock.synchronized {
            guard loop == nil else {
                MobiusHooks.onError("cannot replace the model of a running loop")
                return
            }

            modelToStartFrom = model
        }
    }

    /// Get the current model of the loop that this controller is running, or the most recent model
    /// if it's not running.
    ///
    /// - Returns: a model with the state of the controller
    public func getModel() -> T.Model {
        return lock.synchronized {
            loop?.getMostRecentModel() ?? modelToStartFrom
        }
    }
}
