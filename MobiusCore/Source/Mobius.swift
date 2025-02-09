// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A wrapper around an update function.
///
/// The [update function] is the core of a Mobius loop. It takes a model and an event, and produces an updated model and
/// a list of effects.
///
/// The Update function is declarative, in the sense that it declares what should happen, but doesn’t actually do
/// anything itself. It returns a `Next` that describes the desired changes – possibly a new `Model`, and possibly some
/// `Effect`s that should be executed – but actually changing the `Model` and executing the `Effect`s happens elsewhere.
///
/// The `Update` struct is intended to simplify compositional construction of update functions, but Mobius itself
/// doesn’t currently provide any utilities for this kind of workflow. It is possible to pass a plain function (of type
/// `(Model, Event) -> Next<Model, Effect>` to the Mobius loop instead of explicitly creating an `Update` struct.
///
/// [update function]: https://github.com/spotify/Mobius.swift/wiki/Concepts#update-function
public struct Update<Model, Event, Effect> {
    @usableFromInline let updateClosure: (Model, Event) -> Next<Model, Effect>

    /// Creates an `Update` struct wrapping the provided function.
    public init(_ update: @escaping (Model, Event) -> Next<Model, Effect>) {
        self.updateClosure = update
    }

    /// Invokes the update function.
    @inlinable
    public func update(model: Model, event: Event) -> Next<Model, Effect> {
        return updateClosure(model, event)
    }

    /// Invokes the update function.
    @inlinable
    public func callAsFunction(model: Model, event: Event) -> Next<Model, Effect> {
        return update(model: model, event: event)
    }
}

/// A function used to normalize the initial model of a loop and optionally issue effects when the loop is started.
public typealias Initiate<Model, Effect> = (Model) -> First<Model, Effect>

// MARK: - Building a Mobius Loop

public enum Mobius {

    /// Create a `Builder` to help you configure a `MobiusLoop` before starting it.
    ///
    /// The builder is immutable. When setting various properties, a new instance of a builder will be returned.
    /// It is therefore recommended to chain the loop configuration functions
    ///
    /// Once done configuring the loop you can start the loop using `start(from:)`.
    ///
    /// - Parameters:
    ///   - update: the `Update` function of the loop
    ///   - effectHandler: an instance conforming to `Connectable`. Will be used to handle effects by the loop.
    /// - Returns: a `Builder` instance that you can further configure before starting the loop
    public static func loop<Model, Event, Effect, EffectHandler: Connectable>(
        update: Update<Model, Event, Effect>,
        effectHandler: EffectHandler
    ) -> Builder<Model, Event, Effect> where EffectHandler.Input == Effect, EffectHandler.Output == Event {
        return Builder(
            update: update,
            effectHandler: effectHandler,
            eventSource: AnyConnectable { _ in .init(acceptClosure: { _ in }, disposeClosure: {}) },
            eventConsumerTransformer: { $0 },
            logger: AnyMobiusLogger(NoopLogger())
        )
    }

    /// A convenience version of `loop` that takes an unwrapped update function.
    ///
    /// - Parameters:
    ///   - update: the update function of the loop
    ///   - effectHandler: an instance conforming to `Connectable`. Will be used to handle effects by the loop.
    /// - Returns: a `Builder` instance that you can further configure before starting the loop
    public static func loop<Model, Event, Effect, EffectHandler: Connectable>(
        update: @escaping (Model, Event) -> Next<Model, Effect>,
        effectHandler: EffectHandler
    ) -> Builder<Model, Event, Effect> where EffectHandler.Input == Effect, EffectHandler.Output == Event {
        return self.loop(
            update: Update(update),
            effectHandler: effectHandler
        )
    }

    /// A `Builder` represents a set of options for a Mobius loop.
    ///
    /// Create a builder using `Mobius.loop`, then optionally configure it with the various `with...` methods. Finally,
    /// call `start` to create a `MobiusLoop` (single-threaded), or `makeController` to create a `MobiusController`
    /// (runs on a background queue, can be stopped and resumed).
    public struct Builder<Model, Event, Effect> {
        private let update: Update<Model, Event, Effect>
        private let effectHandler: AnyConnectable<Effect, Event>
        private let eventSource: AnyConnectable<Model, Event>
        private let logger: AnyMobiusLogger<Model, Event, Effect>
        private let eventConsumerTransformer: ConsumerTransformer<Event>

        fileprivate init<EffectHandler: Connectable>(
            update: Update<Model, Event, Effect>,
            effectHandler: EffectHandler,
            eventSource: AnyConnectable<Model, Event>,
            eventConsumerTransformer: @escaping ConsumerTransformer<Event>,
            logger: AnyMobiusLogger<Model, Event, Effect>
        ) where EffectHandler.Input == Effect, EffectHandler.Output == Event {
            self.update = update
            self.effectHandler = AnyConnectable(effectHandler)
            self.eventSource = eventSource
            self.logger = logger
            self.eventConsumerTransformer = eventConsumerTransformer
        }

        /// Return a copy of this builder with a new [event source].
        ///
        /// If a `MobiusLoop` is created from the builder by calling `start`, the event source will be subscribed to
        /// immediately, and the subscription will be disposed when the loop is disposed.
        ///
        /// If a `MobiusController` is created by calling `makeController`, the controller will subscribe to the event
        ///  source each time `start` is called on the controller, and dispose the subscription when `stop` is called.
        ///
        /// - Note: The event source will replace any existing event source.
        ///
        /// - Parameter eventSource: The event source to set on the new builder.
        /// - Returns: An updated Builder.
        ///
        /// [event source]: https://github.com/spotify/Mobius.swift/wiki/Event-Source
        public func withEventSource<Source: EventSource>(_ eventSource: Source) -> Builder where Source.Event == Event {
            return Builder(
                update: update,
                effectHandler: effectHandler,
                eventSource: AnyConnectable { consumer in
                    var disposable: Disposable? = eventSource.subscribe(consumer: consumer)
                    return .init(
                        acceptClosure: { _ in },
                        disposeClosure: {
                            disposable?.dispose()
                            disposable = nil
                        }
                    )
                },
                eventConsumerTransformer: eventConsumerTransformer,
                logger: logger
            )
        }

        /// Return a copy of this builder with a new [event source] using a `Connectable<Model, Event>`.
        ///
        /// If a `MobiusLoop` is created from the builder by calling `start`, the event source will be subscribed to
        /// immediately, and the subscription will be disposed when the loop is disposed.
        ///
        /// If a `MobiusController` is created by calling `makeController`, the controller will subscribe to the event
        /// source each time `start` is called on the controller, and dispose the subscription when `stop` is called.
        ///
        /// The loop will use the `Connectable<Model, Event>` event source,  to invoke the `Connection<Model>`
        /// accept method every time the model changes. This allows to conditionally subscribe to different sources based
        /// on the current state
        ///
        /// - Note: The event source will replace any existing event source.
        ///
        /// - Parameter eventSource: The event source to set on the new builder.
        /// - Returns: An updated Builder.
        ///
        public func withEventSource<Source: Connectable>(_ eventSource: Source) -> Builder where Source.Input == Model, Source.Output == Event {
            return Builder(
                update: update,
                effectHandler: effectHandler,
                eventSource: AnyConnectable(eventSource),
                eventConsumerTransformer: eventConsumerTransformer,
                logger: logger
            )
        }

        /// Return a copy of this builder with a new logger.
        ///
        /// - Note: The logger will replace any existing logger.
        ///
        /// - Parameter logger: The logger to set on the new builder.
        /// - Returns: An updated Builder.
        public func withLogger<Logger: MobiusLogger>(
            _ logger: Logger
        ) -> Builder where Logger.Model == Model, Logger.Event == Event, Logger.Effect == Effect {
            return Builder(
                update: update,
                effectHandler: effectHandler,
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
        /// - Note: The transformer will replace any existing event consumer transformer.
        ///
        /// - Parameter transformer: The transformation to apply to event consumers.
        /// - Returns: An updated Builder.
        public func withEventConsumerTransformer(_ transformer: @escaping ConsumerTransformer<Event>) -> Builder {
            let oldTransfomer = self.eventConsumerTransformer
            return Builder(
                update: update,
                effectHandler: effectHandler,
                eventSource: eventSource,
                eventConsumerTransformer: { consumer in transformer(oldTransfomer(consumer)) },
                logger: logger
            )
        }

        /// Create a `MobiusLoop` from the builder, and optionally dispatch one or more effects.
        ///
        /// - Parameters:
        ///   - initialModel: The model the loop should start with.
        ///   - effects: Zero or more effects to execute immediately.
        public func start(from initialModel: Model, effects: [Effect] = []) -> MobiusLoop<Model, Event, Effect> {
            return MobiusLoop(
                model: initialModel,
                update: update,
                eventSource: eventSource,
                eventConsumerTransformer: eventConsumerTransformer,
                effectHandler: effectHandler,
                effects: effects,
                logger: logger
            )
        }

        /// Create a `MobiusController` from the builder.
        ///
        /// - Parameters:
        ///   - initialModel: The initial default model of the `MobiusController`
        ///   - qos: The Quality of Service class for the controller’s work queue. Default: `.userInitiated`
        public func makeController(
            from initialModel: Model,
            initiate: Initiate<Model, Effect>? = nil,
            qos: DispatchQoS.QoSClass = .userInitiated
        ) -> MobiusController<Model, Event, Effect> {
            return makeController(from: initialModel, initiate: initiate, loopQueue: .global(qos: qos))
        }

        /// Create a `MobiusController` from the builder.
        ///
        /// - Parameters:
        ///   - initialModel: The initial default model of the `MobiusController`
        ///   - initiate: An optional initiator function to invoke each time the controller’s loop is started.
        ///   - loopQueue: The target queue for the `MobiusController`’s work queue. The controller will dispatch events
        ///     and effects on a serial queue that targets this queue.
        ///   - viewQueue: The queue to use to post to the `MobiusController`’s view connection.
        ///     Default: the main queue.
        public func makeController(
            from initialModel: Model,
            initiate: Initiate<Model, Effect>? = nil,
            loopQueue: DispatchQueue,
            viewQueue: DispatchQueue = .main
        ) -> MobiusController<Model, Event, Effect> {
            return MobiusController(
                builder: self,
                initialModel: initialModel,
                initiate: initiate,
                logger: logger,
                loopQueue: loopQueue,
                viewQueue: viewQueue
            )
        }
    }
}
