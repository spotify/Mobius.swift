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

import MobiusCore
import XCTest

public struct EffectRouterSpec<Effect, Event> {
    private let effectRouter: EffectRouter<Effect, Event>

    public static func given(_ effectRouter: EffectRouter<Effect, Event>) -> Self {
        return EffectRouterSpec(effectRouter: effectRouter)
    }

    public func when(_ effects: [Effect]) -> When {
        When(effectRouter: effectRouter, effects: effects)
    }

    public func when(_ effects: Effect...) -> When {
        When(effectRouter: effectRouter, effects: effects)
    }

    public struct When {
        fileprivate let effectRouter: EffectRouter<Effect, Event>
        fileprivate let effects: [Effect]

        public func then(
            _ matchers: Predicate<[Event]>...,
            failFunction: @escaping AssertionFailure = XCTFail
        ) {
            var gotEvents: [Event] = []

            let connection = effectRouter.asConnectable
                .connect { event in
                    gotEvents.append(event)
                }
            defer { connection.dispose() }

            for effect in effects {
                connection.accept(effect)
            }

            for matcher in matchers {
                if case .failure(let message, let file, let line) = matcher(gotEvents) {
                    failFunction(message, file, line)
                }
            }
        }
    }
}

public func expectEvents<Event: Equatable>(
    _ events: Event...,
    file: StaticString = #file,
    line: UInt = #line
) -> Predicate<[Event]> {
    return { gotEvents in
        if events.allSatisfy({ gotEvents.contains($0) }) {
            return .success
        } else {
            return .failure(message: "Expected \(gotEvents) to contain: \(events)", file: file, line: line)
        }
    }
}

public func expectSideEffects<Event: Equatable>(
    file: StaticString = #file,
    line: UInt = #line,
    _ sideEffects: @escaping () -> Void
) -> Predicate<[Event]> {
    return { gotEvents in
        sideEffects()
        return .success
    }
}
