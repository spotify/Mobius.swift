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

/// Protocol for logging init and update calls.
public protocol MobiusLogger: LoopTypes {
    ///  Called right before the `Initiator` function is called.
    ///
    ///  This method mustn't block, as it'll hinder the loop from running. It will be called on the
    ///  same thread as the `Initiator` function.
    ///
    /// - Parameter model: the model that will be passed to the initiator function
    func willInitiate(model: Model)

    /// Called right after the `Initiator` function is called.
    ///
    /// This method mustn't block, as it'll hinder the loop from running. It will be called on the
    /// same thread as the initiator function.
    ///
    /// - Parameters:
    ///     - model: the model that was passed to the initiator
    ///     - first: the resulting `First` instance
    func didInitiate(model: Model, first: First<Model, Effect>)

    /// Called right before the `Update` function is called.
    ///
    /// This method mustn't block, as it'll hinder the loop from running. It will be called on the
    /// same thread as the update function.
    ///
    /// - Parameters:
    ///     - model: the model that will be passed to the update function
    ///     - event: the event that will be passed to the update function
    func willUpdate(model: Model, event: Event)

    /// Called right after the `Update` function is called.
    ///
    /// This method mustn't block, as it'll hinder the loop from running. It will be called on the
    /// same thread as the update function.
    ///
    /// - Parameters:
    ///     - model: the model that was passed to update
    ///     - event: the event that was passed to update
    ///     - result: the `Next` that update returned
    func didUpdate(model: Model, event: Event, next: Next<Model, Effect>)
}

class NoopLogger<T: LoopTypes>: MobiusLogger {
    typealias Model = T.Model
    typealias Event = T.Event
    typealias Effect = T.Effect

    func willInitiate(model: T.Model) {
        // empty
    }

    func didInitiate(model: T.Model, first: First<T.Model, T.Effect>) {
        // empty
    }

    func willUpdate(model: T.Model, event: T.Event) {
        // empty
    }

    func didUpdate(model: T.Model, event: T.Event, next: Next<T.Model, T.Effect>) {
        // empty
    }
}

/// Type-erased `MobiusLogger`.
public class AnyMobiusLogger<T: LoopTypes>: MobiusLogger {
    public typealias Model = T.Model
    public typealias Event = T.Event
    public typealias Effect = T.Effect

    private let willInitiateClosure: (Model) -> Void
    private let didInitiateClosure: (Model, First<Model, Effect>) -> Void
    private let willUpdateClosure: (Model, Event) -> Void
    private let didUpdateClosure: (Model, Event, Next<Model, Effect>) -> Void

    public init<L: MobiusLogger>(_ base: L) where L.Model == Model, L.Event == Event, L.Effect == Effect {
        willInitiateClosure = base.willInitiate
        didInitiateClosure = base.didInitiate
        willUpdateClosure = base.willUpdate
        didUpdateClosure = base.didUpdate
    }

    public func willInitiate(model: T.Model) {
        willInitiateClosure(model)
    }

    public func didInitiate(model: T.Model, first: First<T.Model, T.Effect>) {
        didInitiateClosure(model, first)
    }

    public func willUpdate(model: T.Model, event: T.Event) {
        willUpdateClosure(model, event)
    }

    public func didUpdate(model: T.Model, event: T.Event, next: Next<T.Model, T.Effect>) {
        didUpdateClosure(model, event, next)
    }
}
