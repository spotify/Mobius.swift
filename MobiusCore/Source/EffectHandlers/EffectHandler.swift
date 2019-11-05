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

/// An effect handler is one of the main building blocks in Mobius.
/// Its role is to interpret the `Effect`s which are returned by the `update` function. As a part of this interpretation, it may output events back into the loop.
///
/// An effect handler can be viewed as a generalized function which receives members of its `Effect` type as input, and output members of its `Event`
/// type. This process is not necessarily synchronous and any number of `Event`s could be outputted for a given `Effect`.
///
/// The `connect` function is called to create a connection which can receive effects, output events, and be torn down when it is disconnected from the loop.
/// The `stopHandling` closure you supply is called as a part of the connection being torn down. You must therefore stop outputting events and dispose of any
/// resources you are using when you receive this callback.
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
        payloadHandlerFor: @escaping (Effect) -> HandleEffectWithOutput<Event>?,
        stopHandling: @escaping () -> Void
    ) {
        self.init(connect: { dispatch in
            _EffectHandlerConnection<Effect, Event>(
                sideEffectForEffectWithOutput: { effect, dispatch in
                    if let handleWithDispatch = payloadHandlerFor(effect) {
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
    /// Create a handler for effects which are equal to the `handlesEffect` parameter.
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
            payloadFor: { effect in
                effect == acceptedEffect
                    ? effect
                    : nil
            },
            handlePayload: handle,
            stopHandling: stopHandling
        )
    }
}

public extension EffectHandler {
    /// Create a handler for effects which satisfy the `payloadFor` parameter function.
    ///
    /// - Parameter payloadFor: A function which determines if this effect handler can handle a given effect. If it can handle the effect, return the payload
    /// that should be sent to the `handlePayload` function. If it cannot handle the effect, return `nil`
    /// - Parameter handlePayload: Handle the payloads of effects which satisfy `payloadFor`.
    /// - Parameter stopHandling: Tear down any resources being used by this effect handler.
    init<EffectPayload>(
        payloadFor: @escaping (Effect) -> EffectPayload?,
        handlePayload: @escaping (EffectPayload, @escaping Consumer<Event>) -> Void,
        stopHandling disposable: @escaping () -> Void = {}
    ) {
        self.init(
            payloadHandlerFor: { effect in
                if let payload = payloadFor(effect) {
                    return { dispatch in
                        handlePayload(payload, dispatch)
                    }
                } else {
                    return nil
                }
            },
            stopHandling: disposable
        )
    }
}
