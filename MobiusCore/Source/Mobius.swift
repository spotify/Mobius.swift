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

public protocol LoopTypes {
    associatedtype Model
    associatedtype Event
    associatedtype Effect: Hashable
}

public typealias Update<T: LoopTypes> = (T.Model, T.Event) -> Next<T.Model, T.Effect>

public typealias Initiator<T: LoopTypes> = (T.Model) -> First<T.Model, T.Effect>

public enum Mobius {}

// MARK: - Building a Mobius Loop

public extension Mobius {
    /// Create a `Builder` to help you configure a `MobiusLoop ` before starting it.
    ///
    /// The builder is immutable. When setting various properties, a new instance of a builder will be returned.
    /// It is therefore recommended to chain the loop configuration functions
    ///
    /// Once done configuring the loop you can start the loop using `start(from:)`.
    ///
    /// - Parameters:
    ///   - update: the `Update` function of the loop
    ///   - effectHandler: an instance conforming to the `ConnectableProtocol`. Will be used to handle effects by the loop
    /// - Returns: a `Builder` instance that you can further configure before starting the loop
    static func loop<T: LoopTypes, C: Connectable>(update: @escaping Update<T>, effectHandler: C) -> Builder<T> where C.InputType == T.Effect, C.OutputType == T.Event {
        return Builder<T>(
            update: update,
            effectHandler: effectHandler,
            initiator: { First(model: $0) },
            eventSource: AnyEventSource<T.Event>({ _ in AnonymousDisposable(disposer: {}) }),
            eventQueue: DispatchQueue(label: "event processor"),
            effectQueue: DispatchQueue(label: "effect processor", attributes: .concurrent),
            logger: AnyMobiusLogger(NoopLogger<T>())
        )
    }

    struct Builder<T: LoopTypes> {
        private let update: Update<T>
        private let effectHandler: AnyConnectable<T.Effect, T.Event>
        private let initiator: Initiator<T>
        private let eventSource: AnyEventSource<T.Event>
        private let eventQueue: DispatchQueue
        private let effectQueue: DispatchQueue
        private let logger: AnyMobiusLogger<T>

        fileprivate init<C: Connectable>(
            update: @escaping Update<T>,
            effectHandler: C,
            initiator: @escaping Initiator<T>,
            eventSource: AnyEventSource<T.Event>,
            eventQueue: DispatchQueue,
            effectQueue: DispatchQueue,
            logger: AnyMobiusLogger<T>
        ) where C.InputType == T.Effect, C.OutputType == T.Event {
            self.update = update
            self.effectHandler = AnyConnectable(effectHandler)
            self.initiator = initiator
            self.eventSource = eventSource
            self.eventQueue = eventQueue
            self.effectQueue = effectQueue
            self.logger = logger
        }

        public func withEventSource<ES: EventSource>(_ eventSource: ES) -> Builder<T> where ES.Event == T.Event {
            return Builder<T>(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: AnyEventSource(eventSource),
                eventQueue: eventQueue,
                effectQueue: effectQueue,
                logger: logger
            )
        }

        public func withInitiator(_ initiator: @escaping Initiator<T>) -> Builder<T> {
            return Builder<T>(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventQueue: eventQueue,
                effectQueue: effectQueue,
                logger: logger
            )
        }

        public func withEventQueue(_ eventQueue: DispatchQueue) -> Builder<T> {
            return Builder<T>(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventQueue: eventQueue,
                effectQueue: effectQueue,
                logger: logger
            )
        }

        public func withEffectQueue(_ effectQueue: DispatchQueue) -> Builder<T> {
            return Builder<T>(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventQueue: eventQueue,
                effectQueue: effectQueue,
                logger: logger
            )
        }

        public func withLogger<L: MobiusLogger>(_ logger: L) -> Builder<T> where L.Model == T.Model, L.Event == T.Event, L.Effect == T.Effect {
            return Builder<T>(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventQueue: eventQueue,
                effectQueue: effectQueue,
                logger: AnyMobiusLogger(logger)
            )
        }

        @available(*, deprecated, message: "use withLogger instead")
        public func logger<L: MobiusLogger>(_ logger: L) -> Builder<T> where L.Model == T.Model, L.Event == T.Event, L.Effect == T.Effect {
            return withLogger(logger)
        }

        public func start(from initialModel: T.Model) -> MobiusLoop<T> {
            return MobiusLoop.createLoop(
                update: update,
                effectHandler: effectHandler,
                initialModel: initialModel,
                initiator: initiator,
                eventSource: eventSource,
                eventQueue: eventQueue,
                effectQueue: effectQueue,
                logger: logger
            )
        }
    }
}

class LoggingInitiator<T: LoopTypes> {
    private let realInit: Initiator<T>
    private let willInit: (T.Model) -> Void
    private let didInit: (T.Model, First<T.Model, T.Effect>) -> Void

    init<L: MobiusLogger>(_ realInit: @escaping Initiator<T>, _ logger: L) where L.Model == T.Model, L.Event == T.Event, L.Effect == T.Effect {
        self.realInit = realInit
        willInit = logger.willInitiate
        didInit = logger.didInitiate
    }

    func initiate(_ model: T.Model) -> First<T.Model, T.Effect> {
        willInit(model)
        let result = realInit(model)
        didInit(model, result)

        return result
    }
}

class LoggingUpdate<T: LoopTypes> {
    private let realUpdate: Update<T>
    private let willUpdate: (T.Model, T.Event) -> Void
    private let didUpdate: (T.Model, T.Event, Next<T.Model, T.Effect>) -> Void

    init<L: MobiusLogger>(_ realUpdate: @escaping Update<T>, _ logger: L) where L.Model == T.Model, L.Event == T.Event, L.Effect == T.Effect {
        self.realUpdate = realUpdate
        willUpdate = logger.willUpdate
        didUpdate = logger.didUpdate
    }

    func update(_ model: T.Model, _ event: T.Event) -> Next<T.Model, T.Effect> {
        willUpdate(model, event)
        let result = realUpdate(model, event)
        didUpdate(model, event, result)

        return result
    }
}
