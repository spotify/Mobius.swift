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

/// An `EffectHandler` is one of the main building blocks in Mobius.
/// Its role is to interpret the `Effect`s which are returned by the `update` function. As a part of this interpretation, an `EffectHandler` may output events
/// back into the loop.
///
/// An `EffectHandler` can be viewed as a generalized function which receives members of its `Effect` type as input, and output members of its `Event`
/// type. This process is not necessarily synchronous and any number of `Event`s could be outputted for a given `Effect`.
///
/// The `connect` function is called when an `EffectHandler` should start handling effects. The closure you supply to `stopHandling` will be called when
/// this connection is torn down. You must therefore dispose of any resources you are using when you receive this callback.
///
/// Note: Sending events from your `EffectHandler` after `stopHandling` returns __will__ cause a runtime error.
public struct EffectHandler<Effect, Event> {
    private let connectFn: (@escaping Consumer<Event>) -> _EffectHandlerConnection<Effect, Event>
    fileprivate init(
        connect: @escaping (@escaping Consumer<Event>) -> _EffectHandlerConnection<Effect, Event>
    ) {
        connectFn = connect
    }

    /// Start handling effects.
    /// An `_EffectHandlerConnection` is returned which can handle effects and can be torn down when it should stop handling events.
    /// - Parameter output: a `Consumer` which accepts your `Event` type. This will be used as the `EffectHandler`'s output.
    public func connect(_ output: @escaping Consumer<Event>) -> _EffectHandlerConnection<Effect, Event> {
        return connectFn(output)
    }
}

private typealias HandleEffectWithOutput<Event> = (@escaping Consumer<Event>) -> Void
private extension EffectHandler {
    init(
        canHandle: @escaping (Effect) -> HandleEffectWithOutput<Event>?,
        stopHandling: @escaping () -> Void
    ) {
        self.init(connect: { dispatch in
            _EffectHandlerConnection<Effect, Event>(
                canHandle: { effect, dispatch in
                    if let handleWithDispatch = canHandle(effect) {
                        return { handleWithDispatch(dispatch) }
                    } else {
                        return nil
                    }
                },
                output: dispatch,
                disposable: AnonymousDisposable(disposer: stopHandling)
            )
        })
    }
}

public extension EffectHandler where Effect: Equatable {
    /// Create a handler for effects which are equal to the `acceptsEffect` parameter.
    ///
    /// - Parameter handlesEffect: a constant effect which should be handled by this effect handler.
    /// - Parameter handle: handle effects which are equal to `handlesEffect`.
    /// - Parameter stopHandling: Tear down any resources being used by this effect handler
    init(
        handlesEffect acceptedEffect: Effect,
        handle: @escaping (Effect, @escaping Consumer<Event>) -> Void,
        stopHandling: @escaping () -> Void = {}
    ) {
        self.init(
            canHandle: { effect in
                effect == acceptedEffect
                    ? effect
                    : nil
            },
            handle: handle,
            stopHandling: stopHandling
        )
    }
}

public extension EffectHandler {
    /// Create a handler for effects which satisfy the `canHandle` parameter function.
    ///
    /// - Parameter canHandle: A function which determines if this EffectHandler can handle a given effect. If it can handle the effect, return the payload
    /// that should be sent as input to the `handle` function. If it cannot handle the effect, return `nil`
    /// - Parameter handleEffect: Handle the payloads of effects which satisfy `canHandle`.
    /// - Parameter stopHandling: Tear down any resources being used by this effect handler.
    init<EffectPayload>(
        canHandle: @escaping (Effect) -> EffectPayload?,
        handle: @escaping (EffectPayload, @escaping Consumer<Event>) -> Void,
        stopHandling disposable: @escaping () -> Void = {}
    ) {
        self.init(
            canHandle: { effect in
                if let payload = canHandle(effect) {
                    return { dispatch in
                        handle(payload, dispatch)
                    }
                } else {
                    return nil
                }
            },
            stopHandling: disposable
        )
    }
}
