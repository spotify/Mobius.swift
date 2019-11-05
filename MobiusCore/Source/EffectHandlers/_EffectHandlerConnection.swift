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

public typealias SideEffect = () -> Void
// swiftlint:disable type_name
/// An `_EffectHandlerConnection` describes the lifecycle of an effect handler. It can receive effects, and output events to its `output` `Consumer`.
/// The `_` in the name denotes that while this class needs to be exposed publicly, you should not depend on it directly as a user of Mobius.
public final class _EffectHandlerConnection<Effect, Event>: Disposable {
    private let sideEffectForEffectWithOutput: (Effect, @escaping Consumer<Event>) -> SideEffect?
    // We cannot know if this `Consumer` is internally thread-safe. The thread-safety is therefore delegated to the
    // `output` instance function.
    private var unsafeOutput: Consumer<Event>?
    // We cannot know if this `Disposable` is internally thread-safe. The thread-safety is therefore delegated to the
    // `dispose` instance function.
    private let unsafeDispose: Disposable
    private let lock = Lock()

    init(
        sideEffectForEffectWithOutput: @escaping (Effect, @escaping Consumer<Event>) -> SideEffect?,
        output unsafeOutput: @escaping Consumer<Event>,
        disposable unsafeDispose: Disposable
    ) {
        self.sideEffectForEffectWithOutput = sideEffectForEffectWithOutput
        self.unsafeOutput = unsafeOutput
        self.unsafeDispose = unsafeDispose
    }

    /// Return an optional `SideEffect` for a given `Effect`.
    /// `SideEffect` is the effectful interpretation of the `Effect` data, and will be `nil` if the effect could not be handled.
    /// 
    /// Note: Execution of the `SideEffect` function should never be deferred. Executing a `SideEffect` after `dispose`
    /// has returned may cause runtime exceptions. `SideEffect` itself may internally be concurrent.
    ///
    /// - Parameter effect: the effect in question
    public func sideEffectFor(_ effect: Effect) -> SideEffect? {
        return sideEffectForEffectWithOutput(effect, output)
    }

    /// Tear down the resources being consumed by this `_EffectHandlerConnection`.
    /// Any events sent by the `_EffectHandlerConnection` after this function returns will result in a runtime exception.
    public func dispose() {
        self.lock.synchronized {
            unsafeDispose.dispose()
            unsafeOutput = nil
        }
    }

    private func output(event: Event) {
        self.lock.synchronized {
            guard let unsafeOutput = unsafeOutput else {
                MobiusHooks.onError("Attempted to dispatch event \(event), but the connection has already been disposed.")
                return
            }
            unsafeOutput(event)
        }
    }

    deinit {
        dispose()
    }
}
