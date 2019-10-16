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

@testable import MobiusCore
import Nimble
import Quick

/*
 Test that effects happen in a reasonable order.

 When dispatching multiple effects in an initator or update function, Mobius does not guarantee that the effects are
 processed in any particular order.

 However, if effects are dispatched from two different events, it is reasonable to expect all the effects from the first
 event to be dispatched before any effect from the second event. This property isn’t strictly necessary, but violating
 it would likely lead to confusion and frustration for no great benefit.
 */

class SequencingTests: QuickSpec {
    private typealias Model = Void

    // In Swift 5.2, we can remove `Int` and the explicit implementation of <
    private enum Event: Int, Comparable {
        case event1
        case event2
        case event3

        static func < (lhs: Event, rhs: Event) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }

    // Our effect is an arbitrary integer tagged with the event it originated from.
    private struct Effect: Equatable, CustomStringConvertible {
        let event: Event
        let value: Int

        var description: String {
            return "(.\(event), \(value))"
        }
    }

    private static func update(_: (), event: Event) -> Next<Model, Effect> {
        // Dispatch any number of values tagged with the current event.
        func dispatch(values: Int...) -> Next<Model, Effect> {
            return .dispatchEffects(values.map { Effect(event: event, value: $0) })
        }

        switch event {
        case .event1:
            return dispatch(values: 1)
        case .event2:
            return dispatch(values: 1, 2, 3)
        case .event3:
            return dispatch(values: 1, 2)
        }
    }

    private class EffectHandler: Connectable {
        typealias InputType = Effect
        typealias OutputType = Event

        private (set) var recievedEffects = [Effect]()

        func connect(_ consumer: @escaping (Event) -> Void) -> Connection<Effect> {
            var dispatchedEvent2 = false
            var dispatchedEvent3 = false

            let accept = { (effect: Effect) in
                self.recievedEffects.append(effect)

                // The first encountered effect from a given event triggers the next event.
                switch effect.event {
                case .event1 where !dispatchedEvent2:
                    consumer(.event2)
                    // Note that dispatchedEvent2 is set _after_ calling the event consumers. This can cause surprising
                    // reentrancy problems if the consumer dispatches events greedily. We want to avoid such surprises
                    // in single-threaded Mobius usage, so the test will fail if that happens because there will be
                    // excess effects.
                    dispatchedEvent2 = true
                case .event2 where !dispatchedEvent3:
                    consumer(.event3)
                    dispatchedEvent3 = true
                default:
                    break
                }
            }

            return Connection(acceptClosure: accept, disposeClosure: {})
        }
    }


    override func spec() {
        describe("MobiusLoop") {
            var loop: MobiusLoop<Model, Event, Effect>!
            var handler: EffectHandler!
            var dispatchedEffects: [Effect] {
                return handler.recievedEffects
            }

            beforeEach {
                handler = EffectHandler()

                loop = Mobius.loop(update: SequencingTests.update, effectHandler: handler)
                    .start(from: ())
            }

            describe("when dispatching an event that triggers effect-event sequences") {
                beforeEach {
                    loop.dispatchEvent(.event1)
                }

                it("produces all expected expects (and nothing else)") {
                    let expectedEffects = [
                        Effect(event: .event1, value: 1),
                        Effect(event: .event2, value: 1),
                        Effect(event: .event2, value: 2),
                        Effect(event: .event2, value: 3),
                        Effect(event: .event3, value: 1),
                        Effect(event: .event3, value: 2),
                    ]

                    expect(dispatchedEffects).to(contain(expectedEffects))
                    expect(dispatchedEffects.count).to(equal(expectedEffects.count))
                }

                it("maintains partial ordering by originating event") {
                    print(dispatchedEffects)

                    // Gather pairs of effects where the first came from a later event than the second.
                    let invalidPairs = dispatchedEffects.pairs().filter { $0.event > $1.event }

                    expect(invalidPairs).to(beEmpty())
                }
            }
        }
    }
}

private extension Collection {
    // Returns a sequence of the adjacent pairs in an array. For example, [1, 2, 3].pairs() produces (1,2), (2,3).
    func pairs() -> AnySequence<(Element, Element)> {
        return AnySequence(zip(self, self.dropFirst()))
    }
}
