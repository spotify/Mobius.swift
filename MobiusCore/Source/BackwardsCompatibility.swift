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

@available(*, deprecated, renamed: "Initiate")
public typealias Initiator<Model, Effect> = Initiate<Model, Effect>

public extension First {
    /// A Boolean indicating whether the `First` object has any effects or not.
    @available(*, deprecated, message: "use !effects.isEmpty instead")
    var hasEffects: Bool { return !effects.isEmpty }
}

public extension First where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    init(model: Model, effects: Set<Effect>) {
        self.model = model
        self.effects = Array(effects)
    }
}

public extension Next {
    /// A Boolean indicating whether the `Next` object has any effects or not.
    @available(*, deprecated, message: "use !effects.isEmpty instead")
    var hasEffects: Bool { return !effects.isEmpty }
}

public extension Next where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    static func next(_ model: Model, effects: Set<Effect>) -> Next<Model, Effect> {
        return .next(model, effects: Array(effects))
    }

    @available(*, deprecated, message: "use array of effects instead")
    static func dispatchEffects(_ effects: Set<Effect>) -> Next<Model, Effect> {
        return .dispatchEffects(Array(effects))
    }
}

public extension Mobius.Builder {
    /// `MobiusLoop` no longer has built-in knowledge of dispatch queues. If you need to work with a loop
    /// asynchronously, use `MobiusController`.
    ///
    /// `Mobius.Builder.makeController` has a form which lets you specify a queue for it to operate the loop on. There
    /// are no longer separate event and effect queues.
    @available(*, unavailable, message: "handle dispatching manually, or use MobiusController")
    func withEventQueue(_ eventQueue: DispatchQueue) -> Mobius.Builder<Model, Event, Effect> {
        return self
    }

    /// `MobiusLoop` no longer has built-in knowledge of dispatch queues. If you need to work with a loop
    /// asynchronously, use `MobiusController`.
    ///
    /// `Mobius.Builder.makeController` has a form which lets you specify a queue for it to operate the loop on. There
    /// are no longer separate event and effect queues.
    @available(*, unavailable, message: "handle dispatching manually, or use MobiusController")
    func withEffectQueue(_ effectQueue: DispatchQueue) -> Mobius.Builder<Model, Event, Effect> {
        return self
    }

    /// For `MobiusLoop`s, explicit initiators are no longer supported. You can now pass a list of effects directly to
    /// `Mobius.Builder.start`, along with the correct initial model.
    ///
    /// For `MobiusController`s, `initiate` is an optional argument to `Mobius.Builder.makeController`.
    @available(*, deprecated, message:
    "initiators are deprecated for raw loops. For MobiusController, pass the initiator to makeController instead")
    func withInitiator(_ initiate: @escaping Initiate<Model, Effect>) -> Mobius.Builder<Model, Event, Effect> {
        return withInitiate(initiate)
    }
}

public extension MobiusLoop {
    @available(*, deprecated, renamed: "latestModel")
    func getMostRecentModel() -> Model? {
        return latestModel
    }
}

public extension MobiusController {
    @available(*, deprecated, message: "use `Mobius.Builder.makeController` instead")
    convenience init(builder: Mobius.Builder<Model, Event, Effect>, defaultModel: Model) {
        self.init(
            builder: builder,
            initialModel: defaultModel,
            loopQueue: .global(qos: .userInitiated),
            viewQueue: .main
        )
    }

    @available(*, deprecated, renamed: "model")
    func getModel() -> Model {
        return model
    }

    @available(*, deprecated, renamed: "running")
    var isRunning: Bool { return running }
}

@available(*, deprecated, message: "use `EffectRouter` instead")
public protocol EffectPredicate {
    associatedtype Effect
    func canAccept(_ effect: Effect) -> Bool
}

@available(*, deprecated, message: "use `EffectRouter` instead")
public protocol ConnectableWithPredicate: Connectable, EffectPredicate {}

@available(*, deprecated, message: "use `EffectRouter` instead")
public protocol ConsumerWithPredicate: EffectPredicate {
    func accept(_ effect: Effect)
}

@available(*, deprecated, message: "use `EffectRouter` instead")
public protocol ActionWithPredicate: EffectPredicate {
    func run()
}

@available(*, deprecated, message: "use `EffectRouter` instead")
public protocol FunctionWithPredicate: EffectPredicate {
    associatedtype Event

    func apply(_ effect: Effect) -> Event
}

@available(*, deprecated, message: "use `EffectRouter` instead")
public extension EffectRouterBuilder {
    /// Add a filtered `Connectable` for handling effects of a given type. The `Connectable` `Connection` will be invoked for
    /// each incoming effect object that passes its `canAccept` call.
    ///
    /// - Parameters:
    ///   - connectable: The `Connectable` which handles an effect
    /// - Returns: This builder.
    func addConnectable<C: Connectable & EffectPredicate>(_ connectable: C) -> EffectRouterBuilder<Input, Output> where C.Input == Input, C.Output == Output, C.Effect == Input {
        return addConnectable(connectable, predicate: connectable.canAccept)
    }

    // If `function` produces an output that is not nil, it will be passed to the connected consumer. If nil is produced
    // it will not be passed to the consumer
    func addFunction(_ function: @escaping (Input) -> Output?, predicate: @escaping (Input) -> Bool) -> EffectRouterBuilder<Input, Output> {
        let connectable = ClosureConnectable<Input, Output>(function)
        return addConnectable(connectable, predicate: predicate)
    }

    func addFunction<F: FunctionWithPredicate>(_ function: F, queue: DispatchQueue? = nil) -> EffectRouterBuilder<Input, Output> where F.Effect == Input, F.Event == Output {
        let connectable = ClosureConnectable<Input, Output>(function.apply, queue: queue)
        return addConnectable(connectable, predicate: function.canAccept)
    }

    func addConsumer<C: ConsumerWithPredicate>(_ consumer: C, queue: DispatchQueue? = nil) -> EffectRouterBuilder<Input, Output> where C.Effect == Input {
        let connectable = ClosureConnectable<Input, Output>(consumer.accept, queue: queue)
        return addConnectable(connectable, predicate: consumer.canAccept)
    }

    func addAction<A: ActionWithPredicate>(_ action: A, queue: DispatchQueue? = nil) -> EffectRouterBuilder<Input, Output> where A.Effect == Input {
        let connectable = ClosureConnectable<Input, Output>(action.run, queue: queue)
        return addConnectable(connectable, predicate: action.canAccept)
    }
}

public extension Connectable {
    @available(*, deprecated, renamed: "Input")
    typealias InputType = Input

    @available(*, deprecated, renamed: "Output")
    typealias OutputType = Output
}

@available(*, deprecated)
public typealias ConnectClosure<InputType, OutputType> = (@escaping Consumer<OutputType>) -> Connection<InputType>

public extension Connection {
    @available(*, deprecated, renamed: "Value")
    typealias ValueType = Value
}

public extension AnyEventSource {
    @available(*, deprecated, renamed: "Event")
    typealias AnEvent = Event
}

/// The `NoEffect` type can be used to signal that some data passing through a Mobius loop cannot have any effects.
@available(*, deprecated, renamed: "Never")
public typealias NoEffect = Never
