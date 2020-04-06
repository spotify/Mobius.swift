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

/// Protocol for logging init and update calls.
public protocol MobiusLogger {
    associatedtype Model
    associatedtype Event
    associatedtype Effect

    ///  Called right before the `Initiate` function is called.
    ///
    ///  This method mustn't block, as it'll hinder the loop from running. It will be called on the
    ///  same thread as the `Initiate` function.
    ///
    /// - Parameter model: the model that will be passed to the initiate function
    func willInitiate(model: Model)

    /// Called right after the `Initiate` function is called.
    ///
    /// This method mustn't block, as it'll hinder the loop from running. It will be called on the
    /// same thread as the initiate function.
    ///
    /// - Parameters:
    ///     - model: the model that was passed to the initiate function
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

public extension MobiusLogger {
    func willInitiate(model: Model) {}
    func didInitiate(model: Model, first: First<Model, Effect>) {}
    func willUpdate(model: Model, event: Event) {}
    func didUpdate(model: Model, event: Event, next: Next<Model, Effect>) {}
}

final class NoopLogger<Model, Event, Effect>: MobiusLogger {}

/// Type-erased wrapper for `MobiusLogger`s
public final class AnyMobiusLogger<Model, Event, Effect>: MobiusLogger {
    private let willInitiateClosure: (Model) -> Void
    private let didInitiateClosure: (Model, First<Model, Effect>) -> Void
    private let willUpdateClosure: (Model, Event) -> Void
    private let didUpdateClosure: (Model, Event, Next<Model, Effect>) -> Void

    /// Creates a type-erased `MobiusLogger` that wraps the given instance.
    public init<Logger: MobiusLogger>(
        _ logger: Logger
    ) where Logger.Model == Model, Logger.Event == Event, Logger.Effect == Effect {
        if let anyLogger = logger as? AnyMobiusLogger {
            willInitiateClosure = anyLogger.willInitiateClosure
            didInitiateClosure = anyLogger.didInitiateClosure
            willUpdateClosure = anyLogger.willUpdateClosure
            didUpdateClosure = anyLogger.didUpdateClosure
        } else {
            willInitiateClosure = logger.willInitiate
            didInitiateClosure = logger.didInitiate
            willUpdateClosure = logger.willUpdate
            didUpdateClosure = logger.didUpdate
        }
    }

    public func willInitiate(model: Model) {
        willInitiateClosure(model)
    }

    public func didInitiate(model: Model, first: First<Model, Effect>) {
        didInitiateClosure(model, first)
    }

    public func willUpdate(model: Model, event: Event) {
        willUpdateClosure(model, event)
    }

    public func didUpdate(model: Model, event: Event, next: Next<Model, Effect>) {
        didUpdateClosure(model, event, next)
    }
}
