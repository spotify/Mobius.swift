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

private enum Effect: Equatable {
    case effect1
    case effect2
}

private enum Event: Equatable {
    case eventForEffect1
    case eventForEffect2
}

class EffectRouterDSLTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        context("Effect routers based on constants") {
            it("Supports routing an effect handler") {
                var events: [Event] = []
                var wasDisposed = false
                let effectHandler = EffectHandler<Effect, Event>(
                    handle: { effect, dispatch in
                        expect(effect).to(equal(.effect1))
                        dispatch(.eventForEffect1)
                    },
                    disposable: AnonymousDisposable {
                        wasDisposed = true
                    }
                )
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1).to(effectHandler)
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                dslHandler.accept(.effect2)
                expect(events).to(equal([.eventForEffect1]))

                dslHandler.dispose()
                expect(wasDisposed).to(beTrue())
            }

            it("Supports routing to a side-effecting function") {
                var effectPerformedCount = 0
                var didDispatchEvents = false
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1).to { effect in
                        expect(effect).to(equal(.effect1))
                        effectPerformedCount += 1
                    }
                    .asConnectable
                    .connect { _ in
                        didDispatchEvents = true
                    }

                dslHandler.accept(.effect1)
                dslHandler.accept(.effect2)
                expect(effectPerformedCount).to(equal(1))
                expect(didDispatchEvents).to(beFalse())
            }

            it("Supports routing to an event-returning function") {
                var events: [Event] = []
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1).toEvent { effect in
                        expect(effect).to(equal(.effect1))
                        return .eventForEffect1
                    }
                    .routeEffects(equalTo: .effect2).toEvent { effect in
                        expect(effect).to(equal(.effect2))
                        return .eventForEffect2
                    }
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                expect(events).to(equal([.eventForEffect1]))
                dslHandler.accept(.effect2)
                expect(events).to(equal([.eventForEffect1, .eventForEffect2]))
            }
        }

        context("Effect routers based on predicates") {
            it("Supports routing an effect handler") {
                var events: [Event] = []
                var wasDisposed = false
                let effectHandler = EffectHandler<Effect, Event>(
                    handle: { effect, dispatch in
                        expect(effect).to(equal(.effect1))
                        dispatch(.eventForEffect1)
                    },
                    disposable: AnonymousDisposable {
                        wasDisposed = true
                    }
                )
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(matching: { $0 == .effect1 }).to(effectHandler)
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                dslHandler.accept(.effect2)
                expect(events).to(equal([.eventForEffect1]))

                dslHandler.dispose()
                expect(wasDisposed).to(beTrue())
            }

            it("Supports routing to a side-effecting function") {
                var performedEffects: [Effect] = []
                var didDispatchEvents = false
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(matching: { $0 == .effect1 }).to { effect in
                        performedEffects.append(effect)
                    }
                    .asConnectable
                    .connect { _ in
                        didDispatchEvents = true
                    }

                dslHandler.accept(.effect1)
                dslHandler.accept(.effect2)
                expect(performedEffects).to(equal([.effect1]))
                expect(didDispatchEvents).to(beFalse())
            }

            it("Supports routing to an event-returning function") {
                var events: [Event] = []
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(matching: { $0 == .effect1 }).toEvent { effect in
                        expect(effect).to(equal(.effect1))
                        return .eventForEffect1
                    }
                    .routeEffects(matching: { $0 == .effect2 }).toEvent { effect in
                        expect(effect).to(equal(.effect2))
                        return .eventForEffect2
                    }
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                expect(events).to(equal([.eventForEffect1]))
                dslHandler.accept(.effect2)
                expect(events).to(equal([.eventForEffect1, .eventForEffect2]))
            }
        }

        context("Effect routers based on payload extracting functions") {
            it("Supports routing an effect handler") {
                var events: [Event] = []
                var wasDisposed = false
                let effectHandler = EffectHandler<Effect, Event>(
                    handle: { effect, dispatch in
                        expect(effect).to(equal(.effect1))
                        dispatch(.eventForEffect1)
                    },
                    disposable: AnonymousDisposable {
                        wasDisposed = true
                    }
                )
                let payload: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withPayload: payload).to(effectHandler)
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                dslHandler.accept(.effect2)
                expect(events).to(equal([.eventForEffect1]))

                dslHandler.dispose()
                expect(wasDisposed).to(beTrue())
            }

            it("Supports routing to a side-effecting function") {
                var performedEffects: [Effect] = []
                var didDispatchEvents = false
                let payload: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withPayload: payload).to { effect in
                        performedEffects.append(effect)
                    }
                    .asConnectable
                    .connect { _ in
                        didDispatchEvents = true
                    }

                dslHandler.accept(.effect1)
                dslHandler.accept(.effect2)
                expect(performedEffects).to(equal([.effect1]))
                expect(didDispatchEvents).to(beFalse())
            }

            it("Supports routing to an event-returning function") {
                var events: [Event] = []
                let extractEffect1: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let extractEffect2: (Effect) -> Effect? = { $0 == .effect2 ? .effect2 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withPayload: extractEffect1).toEvent { effect in
                        expect(effect).to(equal(.effect1))
                        return .eventForEffect1
                    }
                    .routeEffects(withPayload: extractEffect2).toEvent { effect in
                        expect(effect).to(equal(.effect2))
                        return .eventForEffect2
                    }
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                expect(events).to(equal([.eventForEffect1]))
                dslHandler.accept(.effect2)
                expect(events).to(equal([.eventForEffect1, .eventForEffect2]))
            }
        }
    }
}
