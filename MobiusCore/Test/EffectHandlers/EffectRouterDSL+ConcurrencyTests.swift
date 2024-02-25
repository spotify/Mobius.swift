// Copyright 2019-2024 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@testable import MobiusCore

import Foundation
import Nimble
import Quick

private enum Effect {
    case effect1
    case effect2(param1: Int)
    case effect3(param1: Int, param2: String)
}

private enum Event {
    case eventForEffect1
    case eventForEffect2
    case eventForEffect3
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
final class EffectRouterDSL_ConcurrencyTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("EffectRouter DSL") {
            context("routing to a side-effecting function") {
                it("supports async handlers") {
                    let effectPerformedCount = Synchronized(value: 0)
                    let routerConnection = EffectRouter<Effect, Event>()
                        .routeCase(Effect.effect1).to { () async in
                            effectPerformedCount.value += 1
                        }
                        .routeCase(Effect.effect2).to { (_: Int) async in
                            effectPerformedCount.value += 1
                        }
                        .routeCase(Effect.effect3).to { (_: (_: Int, _: String)) async in
                            effectPerformedCount.value += 1
                        }
                        .asConnectable
                        .connect { _ in }

                    routerConnection.accept(.effect1)
                    expect(effectPerformedCount.value).toEventually(equal(1))

                    routerConnection.accept(.effect2(param1: 123))
                    expect(effectPerformedCount.value).toEventually(equal(2))

                    routerConnection.accept(.effect3(param1: 123, param2: "Foo"))
                    expect(effectPerformedCount.value).toEventually(equal(3))
                }

                it("supports async throwing handlers") {
                    let effectPerformedCount = Synchronized(value: 0)
                    let routerConnection = EffectRouter<Effect, Event>()
                        .routeCase(Effect.effect1).to { () async throws in
                            effectPerformedCount.value += 1
                        }
                        .routeCase(Effect.effect2).to { (_: Int) async throws in
                            effectPerformedCount.value += 1
                        }
                        .routeCase(Effect.effect3).to { (_: (_: Int, _: String)) async throws in
                            effectPerformedCount.value += 1
                        }
                        .asConnectable
                        .connect { _ in }

                    routerConnection.accept(.effect1)
                    expect(effectPerformedCount.value).toEventually(equal(1))

                    routerConnection.accept(.effect2(param1: 123))
                    expect(effectPerformedCount.value).toEventually(equal(2))

                    routerConnection.accept(.effect3(param1: 123, param2: "Foo"))
                    expect(effectPerformedCount.value).toEventually(equal(3))
                }
            }

            context("routing to a event-returning function") {
                it("supports async handlers") {
                    let events: Synchronized<[Event]> = .init(value: [])
                    let routerConnection = EffectRouter<Effect, Event>()
                        .routeCase(Effect.effect1).to { () async -> Event in
                            .eventForEffect1
                        }
                        .routeCase(Effect.effect2).to { (_: Int) async -> Event in
                            .eventForEffect2
                        }
                        .routeCase(Effect.effect3).to { (_: (_: Int, _: String)) async -> Event in
                            .eventForEffect3
                        }
                        .asConnectable
                        .connect { event in events.mutate { events in events.append(event) } }

                    routerConnection.accept(.effect1)
                    expect(events.value).toEventually(equal([.eventForEffect1]))

                    routerConnection.accept(.effect2(param1: 123))
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect2]))

                    routerConnection.accept(.effect3(param1: 123, param2: "Foo"))
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect2, .eventForEffect3]))
                }

                it("supports async throwing handlers") {
                    let events: Synchronized<[Event]> = .init(value: [])
                    let routerConnection = EffectRouter<Effect, Event>()
                        .routeCase(Effect.effect1).to { () async throws -> Event in
                            .eventForEffect1
                        }
                        .routeCase(Effect.effect2).to { (_: Int) async throws -> Event in
                            .eventForEffect2
                        }
                        .routeCase(Effect.effect3).to { (_: (_: Int, _: String)) async throws -> Event in
                            .eventForEffect3
                        }
                        .asConnectable
                        .connect { event in events.mutate { events in events.append(event) } }

                    routerConnection.accept(.effect1)
                    expect(events.value).toEventually(equal([.eventForEffect1]))

                    routerConnection.accept(.effect2(param1: 123))
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect2]))

                    routerConnection.accept(.effect3(param1: 123, param2: "Foo"))
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect2, .eventForEffect3]))
                }
            }

            context("routing to a sequence-returning function") {
                it("supports async handlers") {
                    let events: Synchronized<[Event]> = .init(value: [])
                    let routerConnection = EffectRouter<Effect, Event>()
                        .routeCase(Effect.effect1).to { () async -> AsyncStream<Event> in
                            AsyncStream { continuation in
                                continuation.yield(.eventForEffect1)
                                continuation.yield(.eventForEffect1)
                                continuation.finish()
                            }
                        }
                        .routeCase(Effect.effect2).to { (_: Int) async -> AsyncStream<Event> in
                            AsyncStream { continuation in
                                continuation.yield(.eventForEffect2)
                                continuation.yield(.eventForEffect2)
                                continuation.finish()
                            }
                        }
                        .routeCase(Effect.effect3).to { (_: (_: Int, _: String)) async -> AsyncStream<Event> in
                            AsyncStream { continuation in
                                continuation.yield(.eventForEffect3)
                                continuation.yield(.eventForEffect3)
                                continuation.finish()
                            }
                        }
                        .asConnectable
                        .connect { event in events.mutate { events in events.append(event) } }

                    routerConnection.accept(.effect1)
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect1]))

                    routerConnection.accept(.effect2(param1: 123))
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect1, .eventForEffect2, .eventForEffect2]))

                    routerConnection.accept(.effect3(param1: 123, param2: "Foo"))
                    expect(events.value).toEventually(equal([.eventForEffect1, .eventForEffect1, .eventForEffect2, .eventForEffect2, .eventForEffect3, .eventForEffect3]))
                }
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private final class UncheckedBox<T>: @unchecked Sendable {
    var t: T?
}

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private func asyncExpect<T: Sendable>(
    file: FileString = #file,
    line: UInt = #line,
    _ expression: @autoclosure @escaping @Sendable () -> (() async throws -> T?)
) -> Expectation<T> {
    expect(file: file, line: line) {
        let box = UncheckedBox<T>()
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            defer { semaphore.signal() }
            box.t = try await expression()()
        }
        semaphore.wait()

        return box.t
    }
}
