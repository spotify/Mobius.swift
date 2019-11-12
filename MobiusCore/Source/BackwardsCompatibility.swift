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

public extension First where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    init(model: Model, effects: Set<Effect>) {
        self.model = model
        self.effects = Array(effects)
    }
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

public extension MobiusLoop {
    @available(*, deprecated, message: "use latestModel of effects instead")
    func getMostRecentModel() -> Model? {
        return latestModel
    }
}

public extension MobiusController {
    @available(*, deprecated, message: "use `Mobius.Builder.makeController` instead")
    convenience init(builder: Mobius.Builder<Model, Event, Effect>, defaultModel: Model) {
        self.init(builder: builder, initialModel: defaultModel)
    }
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
    func addConnectable<C: Connectable & EffectPredicate>(_ connectable: C) -> EffectRouterBuilder<Input, Output> where C.InputType == Input, C.OutputType == Output, C.Effect == Input {
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
