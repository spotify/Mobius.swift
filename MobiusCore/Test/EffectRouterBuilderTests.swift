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
@testable import MobiusCore
import Nimble
import Quick

// swiftlint:disable type_body_length file_length

class EffectRouterBuilderTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("EffectRouterBuilder") {
            context("when adding an `EffectHandler`") {
                var connection: Connection<Int>!
                var receivedEvents: [Int]!

                beforeEach {
                    // An effect handler which only accepts the number 1. When it gets a 1, it emits a 1 as its event.
                    let effectHandler1 = EffectHandler.makeEffectHandler(acceptsEffect: 1, handleEffect: handleEffect)
                    // An effect handler which only accepts the number 2. When it gets a 2, it emits a 2 as its event.
                    let effectHandler2 = EffectHandler.makeEffectHandler(acceptsEffect: 2, handleEffect: handleEffect)
                    connection = EffectRouterBuilder()
                        .addEffectHandler(effectHandler1)
                        .addEffectHandler(effectHandler2)
                        .build()
                        .connect { event in
                            receivedEvents.append(event)
                        }
                    receivedEvents = []
                }
                afterEach {
                    connection.dispose()
                }

                it("dispatches effects which satisfy the effect handler's `canAccept` function") {
                    connection.accept(1)
                    connection.accept(2)
                    expect(receivedEvents).to(equal([1, 2]))
                }

                it("crashes if an effect which no EffectHandler can handle is emitted") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }

                    connection.accept(3)

                    expect(didCrash).to(beTrue())
                }
            }

            context("when multiple `EffectHandler`s handle the same effect") {
                var connection: Connection<Int>!
                beforeEach {
                    let effectHandler1 = EffectHandler.makeEffectHandler(acceptsEffect: 1, handleEffect: handleEffect)
                    let effectHandler2 = EffectHandler.makeEffectHandler(acceptsEffect: 1, handleEffect: handleEffect)
                    connection = EffectRouterBuilder()
                        .addEffectHandler(effectHandler1)
                        .addEffectHandler(effectHandler2)
                        .build()
                        .connect { _ in }
                }
                afterEach {
                    connection.dispose()
                }

                it("should crash") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }
                    connection.accept(1)
                    expect(didCrash).to(beTrue())
                }
            }
        }
    }
}

private func handleEffect(effect: Int, dispatch: @escaping Consumer<Int>) {
    dispatch(effect)
}
