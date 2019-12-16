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

public typealias Update<Model, Event, Effect> = (Model, Event) -> Next<Model, Effect>

public typealias Initiator<Model, Effect> = (Model) -> First<Model, Effect>

public enum Mobius {}

// MARK: - Building a Mobius Loop

public extension Mobius {

    /// Create a `Builder` to help you configure a `MobiusLoop` before starting it.
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
    static func loop<Model, Event, Effect, C: Connectable>(
        update: @escaping Update<Model, Event, Effect>,
        effectHandler: C
    ) -> Builder<Model, Event, Effect> where C.InputType == Effect, C.OutputType == Event {
        return Builder(
            update: update,
            effectHandler: effectHandler,
            initiator: { First(model: $0) },
            eventSource: AnyEventSource({ _ in AnonymousDisposable(disposer: {}) }),
            eventConsumerTransformer: { $0 },
            logger: AnyMobiusLogger(NoopLogger())
        )
    }

    struct Builder<Model, Event, Effect> {
        private let update: Update<Model, Event, Effect>
        private let effectHandler: AnyConnectable<Effect, Event>
        private let initiator: Initiator<Model, Effect>
        private let eventSource: AnyEventSource<Event>
        private let logger: AnyMobiusLogger<Model, Event, Effect>
        private let eventConsumerTransformer: ConsumerTransformer<Event>

        fileprivate init<C: Connectable>(
            update: @escaping Update<Model, Event, Effect>,
            effectHandler: C,
            initiator: @escaping Initiator<Model, Effect>,
            eventSource: AnyEventSource<Event>,
            eventConsumerTransformer: @escaping ConsumerTransformer<Event>,
            logger: AnyMobiusLogger<Model, Event, Effect>
        ) where C.InputType == Effect, C.OutputType == Event {
            self.update = update
            self.effectHandler = AnyConnectable(effectHandler)
            self.initiator = initiator
            self.eventSource = eventSource
            self.logger = logger
            self.eventConsumerTransformer = eventConsumerTransformer
        }

        public func withEventSource<ES: EventSource>(_ eventSource: ES) -> Builder where ES.Event == Event {
            return Builder(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: AnyEventSource(eventSource),
                eventConsumerTransformer: eventConsumerTransformer,
                logger: logger
            )
        }

        public func withInitiator(_ initiator: @escaping Initiator<Model, Effect>) -> Builder {
            return Builder(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventConsumerTransformer: eventConsumerTransformer,
                logger: logger
            )
        }

        public func withLogger<L: MobiusLogger>(_ logger: L) -> Builder where L.Model == Model, L.Event == Event, L.Effect == Effect {
            return Builder(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventConsumerTransformer: eventConsumerTransformer,
                logger: AnyMobiusLogger(logger)
            )
        }


        /// Add a function to transform the event consumers, i.e. functions that take an event and pass it to the
        /// loop’s processing logic. If multiple transformers are supplied, they will be applied in the order they
        /// were specified.
        ///
        /// Note that this is a map over `Consumer<Event>`, not over `Event`.
        ///
        /// - Note: The event consumer transformer can be used to implement custom scheduling, such as marshalling
        /// events to a particular queue or thread. However, correctly managing the logic around this while also
        /// handling loop teardown is tricky; it is recommended that you use `MobiusController` for this purpose, or
        /// at least refer to its implementation.
        ///
        /// - Parameter transformer: The transformation to apply to event consumers.
        /// - Returns: An updated Builder.
        public func withEventConsumerTransformer(_ transformer: @escaping ConsumerTransformer<Event>) -> Builder {
            let oldTransfomer = self.eventConsumerTransformer
            return Builder(
                update: update,
                effectHandler: effectHandler,
                initiator: initiator,
                eventSource: eventSource,
                eventConsumerTransformer: { consumer in transformer(oldTransfomer(consumer)) },
                logger: logger
            )
        }

        public func start(from initialModel: Model) -> MobiusLoop<Model, Event, Effect> {
            return MobiusLoop.createLoop(
                update: update,
                effectHandler: effectHandler,
                initialModel: initialModel,
                initiator: initiator,
                eventSource: eventSource,
                eventConsumerTransformer: eventConsumerTransformer,
                logger: logger
            )
        }

        /// Create a `MobiusController` from the builder
        ///
        /// - Parameters:
        ///   - initialModel: The initial default model of the `MobiusController`
        ///   - qos: The Quality of Service class for the controller’s work queue. Default: `.userInitiated`
        public func makeController(
            from initialModel: Model,
            qos: DispatchQoS.QoSClass = .userInitiated
        ) -> MobiusController<Model, Event, Effect> {
            return makeController(from: initialModel, loopQueue: .global(qos: qos))
        }

        /// Create a `MobiusController` from the builder
        ///
        /// - Parameters:
        ///   - initialModel: The initial default model of the `MobiusController`
        ///   - loopQueue: The target queue for the `MobiusController`’s work queue. The controller will dispatch events
        ///     and effects on a serial queue that targets this queue.
        ///   - viewQueue: The queue to use to post to the `MobiusController`’s view connection.
        ///     Default: the main queue.
        public func makeController(
            from initialModel: Model,
            loopQueue: DispatchQueue,
            viewQueue: DispatchQueue = .main
        ) -> MobiusController<Model, Event, Effect> {
            return MobiusController(
                builder: self,
                initialModel: initialModel,
                loopQueue: loopQueue,
                viewQueue: viewQueue
            )
        }
    }
}

class LoggingInitiator<Model, Effect> {
    private let realInit: Initiator<Model, Effect>
    private let willInit: (Model) -> Void
    private let didInit: (Model, First<Model, Effect>) -> Void

    init<L: MobiusLogger>(_ realInit: @escaping Initiator<Model, Effect>, _ logger: L) where L.Model == Model, L.Effect == Effect {
        self.realInit = realInit
        willInit = logger.willInitiate
        didInit = logger.didInitiate
    }

    func initiate(_ model: Model) -> First<Model, Effect> {
        willInit(model)
        let result = realInit(model)
        didInit(model, result)

        return result
    }
}

class LoggingUpdate<Model, Event, Effect> {
    private let realUpdate: Update<Model, Event, Effect>
    private let willUpdate: (Model, Event) -> Void
    private let didUpdate: (Model, Event, Next<Model, Effect>) -> Void

    init<L: MobiusLogger>(_ realUpdate: @escaping Update<Model, Event, Effect>, _ logger: L) where L.Model == Model, L.Event == Event, L.Effect == Effect {
        self.realUpdate = realUpdate
        willUpdate = logger.willUpdate
        didUpdate = logger.didUpdate
    }

    func update(_ model: Model, _ event: Event) -> Next<Model, Effect> {
        willUpdate(model, event)
        let result = realUpdate(model, event)
        didUpdate(model, event, result)

        return result
    }
}
