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

public extension EffectHandler {
    /// Merge a group of `EffectHandler`s.
    /// Note: Any given `Effect` can be handled by at most  __1__ `EffectHandler`. Handling an `Effect` in more than 1 `EffectHandler` will
    /// cause a runtime crash.
    ///
    /// - Parameter handlers: the `EffectHandler`s which should be merged.
    convenience init(
        _ handlers: EffectHandler<Effect, Event>...
    ) {
        self.init(handlers)
    }

    /// Merge an `Array` of `EffectHandler`s.
    /// Note: Any given `Effect` can be handled by at most  __1__ `EffectHandler`. Handling an `Effect` in more than 1 `EffectHandler` will
    /// cause a runtime crash.
    ///
    /// - Parameter handlers: the `EffectHandler`s which should be merged.
    convenience init(
        _ handlers: [EffectHandler<Effect, Event>]
    ) {
        self.init(
            handleEffect: { effect in EffectHandler.handleEffect(handlers: handlers, effect: effect) },
            stopHandling: { EffectHandler.disposeHandlers(handlers) }
        )
    }

    private static func disposeHandlers(_ handlers: [EffectHandler<Effect, Event>]) {
        for handler in handlers {
            handler.dispose()
        }
    }

    private static func handleEffect(
        handlers: [EffectHandler<Effect, Event>],
        effect: Effect
    ) -> ((@escaping Consumer<Event>) -> Void)? {
        let relevantHandlers = handlers.compactMap { $0.canHandle(effect) }
        if relevantHandlers.count > 1 {
            MobiusHooks.onError("Multiple EffectHandlers found for effect: \(effect). Only one EffectHandler is supported per effect.")
            return nil
        } else {
            return relevantHandlers.first
        }
    }
}
