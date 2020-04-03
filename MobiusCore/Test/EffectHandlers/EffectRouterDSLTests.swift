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
        context("An EffectHandler which always ends as soon as it is called") {
            var wasDisposed: Bool!
            var connection: Connection<Int>!

            beforeEach {
                wasDisposed = false
                connection = EffectRouter<Int, ()>()
                    .routeEffects(equalTo: 1).to { _, callback in
                        callback.end()
                        return AnonymousDisposable {
                            wasDisposed = true
                        }
                    }
                    .asConnectable
                    .connect { _ in }
            }

            it("should not be disposed if `end()` was called") {
                connection.accept(1)
                connection.dispose()

                expect(wasDisposed).to(beFalse())
            }

            it("should not be disposed if the connection is disposed before `end()` is called") {
                connection.dispose()

                expect(wasDisposed).to(beFalse())
            }
        }

        context("An EffectHandler which calls end after some time") {
            var wasDisposed: Bool!
            var connection: Connection<Int>!
            var end: (() -> Void)!

            beforeEach {
                wasDisposed = false
                end = { fail("End should have been set") }
                connection = EffectRouter<Int, ()>()
                    .routeEffects(equalTo: 1).to { _, callback in
                        end = callback.end
                        return AnonymousDisposable {
                            wasDisposed = true
                        }
                    }
                    .asConnectable
                    .connect { _ in }
            }

            it("should not be disposed if `end()` was called") {
                connection.accept(1)
                end()
                connection.dispose()

                expect(wasDisposed).to(beFalse())
            }

            it("should be disposed if `end()` was never called") {
                connection.accept(1)
                connection.dispose()

                expect(wasDisposed).to(beTrue())
            }
        }

        context("Effect routers based on constants") {
            it("Supports routing to an effect handler") {
                var events: [Event] = []
                var wasDisposed = false

                let connection = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1).to { effect, callback in
                        expect(effect).to(equal(.effect1))
                        callback.send(.eventForEffect1)
                        return AnonymousDisposable {
                            wasDisposed = true
                        }
                    }
                    .asConnectable
                    .connect { events.append($0) }

                connection.accept(.effect1)
                expect(events).to(equal([.eventForEffect1]))

                connection.dispose()
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

        context("Effect routers based on parameter extracting functions") {
            it("Supports routing to and receiving events from an effect handler") {
                var events: [Event] = []

                let parameterExtractor: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withParameters: parameterExtractor).to { effect, callback in
                        expect(effect).to(equal(.effect1))
                        callback.send(.eventForEffect1)
                        callback.end()
                        return AnonymousDisposable {}
                    }
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                expect(events).to(equal([.eventForEffect1]))
            }

            it("Supports routing to and disposing an effect handler") {
                var events: [Event] = []
                var wasDisposed = false

                let parameterExtractor: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withParameters: parameterExtractor).to { _, _ in
                        return AnonymousDisposable {
                            wasDisposed = true
                        }
                    }
                    .asConnectable
                    .connect { events.append($0) }

                dslHandler.accept(.effect1)
                dslHandler.dispose()
                expect(wasDisposed).to(beTrue())
            }

            it("Supports routing to a side-effecting function") {
                var performedEffects: [Effect] = []
                var didDispatchEvents = false
                let parameterExtractor: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withParameters: parameterExtractor).to { effect in
                        performedEffects.append(effect)
                    }
                    .asConnectable
                    .connect { _ in
                        didDispatchEvents = true
                    }

                dslHandler.accept(.effect1)
                expect(performedEffects).to(equal([.effect1]))
                expect(didDispatchEvents).to(beFalse())
            }

            it("Supports routing to an event-returning function") {
                var events: [Event] = []
                let extractEffect1: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let extractEffect2: (Effect) -> Effect? = { $0 == .effect2 ? .effect2 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withParameters: extractEffect1).toEvent { effect in
                        expect(effect).to(equal(.effect1))
                        return .eventForEffect1
                    }
                    .routeEffects(withParameters: extractEffect2).toEvent { effect in
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

            it("Supports routing to a Connectable") {
                var dispatchedEvents: [Event] = []
                let parameterExtractor: (Effect) -> Effect? = { $0 == .effect1 ? .effect1 : nil }
                let dslHandler = EffectRouter<Effect, Event>()
                    .routeEffects(withParameters: parameterExtractor).to(EffectConnectable(emitsEvent: .eventForEffect1))
                    .asConnectable
                    .connect { event in
                        dispatchedEvents.append(event)
                    }

                dslHandler.accept(.effect1)
                expect(dispatchedEvents).to(equal([.eventForEffect1]))
            }
        }
    }
}

private class EffectConnectable: Connectable {
    let emitsEvent: Event

    init(emitsEvent event: Event) {
        emitsEvent = event
    }

    func connect(_ consumer: @escaping (Event) -> Void) -> Connection<Effect> {
        return Connection(
            acceptClosure: { _ in
                consumer(self.emitsEvent)
            },
            disposeClosure: {}
        )
    }
}
