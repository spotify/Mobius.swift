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
import MobiusTest
import Nimble
import Quick

final class EffectRouterSpecTests: QuickSpec {
    private enum Effect {
        case one
    }

    override func spec() {
        context("Effect Router Spec") {
            it("supports matching events") {
                let effectRouter = EffectRouter<Effect, String>()
                    .routeCase(Effect.one).toEvent { _ in
                        return "test"
                    }

                EffectRouterSpec.given(effectRouter)
                    .when(.one)
                    .then(
                        expectEvents("test")
                    )
            }

            it("supports checking for side effects") {
                var performedEffect = false
                let effectRouter = EffectRouter<Effect, String>()
                    .routeCase(Effect.one).to { _ in
                        performedEffect = true
                    }

                EffectRouterSpec.given(effectRouter)
                    .when(.one)
                    .then(
                        expectSideEffects {
                            expect(performedEffect).to(beTrue())
                        }
                    )
            }

            it("supports multiple matchers") {
                let effectRouter = EffectRouter<Effect, String>()
                    .routeCase(Effect.one).to { _, callback in
                        callback.end(with: "test1", "test2")
                        return AnonymousDisposable {}
                    }

                EffectRouterSpec.given(effectRouter)
                    .when(.one)
                    .then(
                        expectEvents("test1"),
                        expectEvents("test2"),
                        expectEvents("test1", "test2")
                    )
            }
        }
    }
}
