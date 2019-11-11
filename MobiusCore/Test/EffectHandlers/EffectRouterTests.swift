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

import MobiusCore
import Nimble
import Quick

// swiftlint:disable type_body_length file_length

private enum Effect {
    case effect1
    case effect2
    case multipleHandlersForThisEffect
    case noHandlersForThisEffect
}

private enum Event {
    case eventForEffect1
    case eventForEffect2
}

class EffectRouterTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        context("Router happy paths") {
            var receivedEvents: [Event]!
            var disposed1: Bool!
            var disposed2: Bool!
            var connection: Connection<Effect>!
            var route: Consumer<Effect>!

            beforeEach {
                receivedEvents = []
                disposed1 = false
                disposed2 = false
                let effectHandler1 = EffectHandler<Effect, Event>(
                    handle: { _, dispatch in
                        dispatch(.eventForEffect1)
                    },
                    disposable: AnonymousDisposable {
                        disposed1 = true
                    }
                )
                let effectHandler2 = EffectHandler<Effect, Event>(
                    handle: { _, dispatch in
                        dispatch(.eventForEffect2)
                    },
                    disposable: AnonymousDisposable {
                        disposed2 = true
                    }
                )
                let effect1Path: (Effect) -> Effect? = { effect in
                    effect == .effect1
                        ? effect
                        : nil
                }
                let effect2Path: (Effect) -> Effect? = { effect in
                    effect == .effect2
                        ? effect
                        : nil
                }

                connection = EffectRouter<Effect, Event>()
                    .add(path: effect1Path, to: effectHandler1)
                    .add(path: effect2Path, to: effectHandler2)
                    .asConnectable
                    .connect { event in
                        receivedEvents.append(event)
                    }

                route = connection.accept
            }

            afterEach {
                connection.dispose()
            }

            it("should be able to route to effectHandler1") {
                _ = route(.effect1)
                expect(receivedEvents).to(equal([.eventForEffect1]))
            }

            it("should be able to route to effectHandler1") {
                _ = route(.effect2)
                expect(receivedEvents).to(equal([.eventForEffect2]))
            }

            it("should dispose all existing effect handlers when router is disposed") {
                connection.dispose()
                expect(disposed1).to(beTrue())
                expect(disposed2).to(beTrue())
            }
        }

        context("Router error cases") {
            var didCrash: Bool!
            var route: Consumer<Effect>!
            var dispose: (() -> Void)!

            beforeEach {
                didCrash = false
                MobiusHooks.setErrorHandler { _, _, _ in
                    didCrash = true
                }
                let handler = EffectHandler<Effect, Event>(
                    handle: { _, _ in },
                    disposable: AnonymousDisposable {}
                )
                let duplicatePath: (Effect) -> Effect? = { effect in
                    effect == .multipleHandlersForThisEffect
                        ? effect
                        : nil
                }
                let invalidRouter = EffectRouter()
                    .add(path: duplicatePath, to: handler)
                    .add(path: duplicatePath, to: handler)
                    .asConnectable
                    .connect { _ in }
                route = invalidRouter.accept
                dispose = invalidRouter.dispose
            }

            afterEach {
                dispose()
            }

            it("should crash if more than 1 effect handler could be found") {
                route(.multipleHandlersForThisEffect)

                expect(didCrash).to(beTrue())
            }

            it("should crash if no effect handlers could be found") {
                route(.noHandlersForThisEffect)

                expect(didCrash).to(beTrue())
            }
        }
    }
}
