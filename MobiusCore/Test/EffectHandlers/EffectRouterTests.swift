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
                let effectHandler1 = AnyEffectHandler<Effect, Event> { _, callback in
                    callback.send(.eventForEffect1)
                    return AnonymousDisposable {
                        disposed1 = true
                    }
                }
                let effectHandler2 = AnyEffectHandler<Effect, Event> { _, callback in
                    callback.send(.eventForEffect2)
                    return AnonymousDisposable {
                        disposed2 = true
                    }
                }

                connection = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1).to(effectHandler1)
                    .routeEffects(equalTo: .effect2).to(effectHandler2)
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

            it("should dispose all started effect handlers when router is disposed") {
                _ = route(.effect1)
                _ = route(.effect2)
                connection.dispose()
                expect(disposed1).to(beTrue())
                expect(disposed2).to(beTrue())
            }

            it("should be possible to connect multiple times if the previous connection was closed") {
                var events: [Event] = []
                let router = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1)
                        .to(TestConnectable(dispatchEvent: .eventForEffect1, onDispose: {}))
                    .routeEffects(equalTo: .effect2)
                        .to { _, callback in
                            callback.send(.eventForEffect2)
                            callback.end()
                            return AnonymousDisposable {}
                        }
                    .asConnectable

                let connection1 = router.connect { events.append($0) }
                connection1.dispose()
                let connection2 = router.connect { events.append($0) }

                connection1.accept(.effect1)
                connection2.accept(.effect2)

                expect(events).to(equal([.eventForEffect1, .eventForEffect2]))
            }
        }

        context("Router error cases") {
            var route: Consumer<Effect>!
            var dispose: (() -> Void)!

            beforeEach {
                let handler = AnyEffectHandler<Effect, Event> { _, _ in
                    AnonymousDisposable {}
                }
                let invalidRouter = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .multipleHandlersForThisEffect).to(handler)
                    .routeEffects(equalTo: .multipleHandlersForThisEffect).to(handler)
                    .asConnectable
                    .connect { _ in }
                route = invalidRouter.accept
                dispose = invalidRouter.dispose
            }

            afterEach {
                dispose()
            }

            it("should crash if more than 1 effect handler could be found") {
                expect(route(.multipleHandlersForThisEffect)).to(raiseError())
            }

            it("should crash if no effect handlers could be found") {
                expect(route(.noHandlersForThisEffect)).to(raiseError())
            }

            it("should not be possible to connect multiple times when routing to `Connectable`s") {
                let router = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1)
                        .to(TestConnectable(dispatchEvent: .eventForEffect1, onDispose: {}))
                    .asConnectable

                var connection1: Connection<Effect>?
                var connection2: Connection<Effect>?

                expect(connection1 = router.connect { _ in }).toNot(raiseError())
                expect(connection2 = router.connect { _ in }).to(raiseError())

                connection1?.dispose()
                connection2?.dispose()
            }

            it("should not be possible to connect multiple times when routing to `EffectHandler`s") {
                let router = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect2)
                        .to { _, callback in
                            callback.end()
                            return AnonymousDisposable {}
                        }
                    .asConnectable

                var connection1: Connection<Effect>?
                var connection2: Connection<Effect>?

                expect(connection1 = router.connect { _ in }).toNot(raiseError())
                expect(connection2 = router.connect { _ in }).to(raiseError())

                connection1?.dispose()
                connection2?.dispose()
            }
        }

        context("Router Disposing on Deinit") {
            it("should dispose active `EffectHandler`s when deinitializing") {
                var wasDisposed = false
                var connection: Connection? = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .effect1)
                    .to { _, _ in
                        return AnonymousDisposable {
                            wasDisposed = true
                        }
                    }
                    .asConnectable
                    .connect { _ in }

                connection?.accept(.effect1)
                connection = nil

                expect(wasDisposed).toEventually(beTrue())
            }
        }
    }
}

private class TestConnectable: Connectable {
    private let event: Event
    private let onDispose: () -> Void
    init(dispatchEvent event: Event, onDispose: @escaping () -> Void) {
        self.event = event
        self.onDispose = onDispose
    }
    func connect(_ consumer: @escaping (Event) -> Void) -> Connection<Effect> {
        Connection(
            acceptClosure: { _ in consumer(self.event) },
            disposeClosure: onDispose
        )
    }
}
