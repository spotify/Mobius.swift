// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import MobiusCore
import Nimble
import Quick

private typealias Model = Int

private enum Event: String, CustomStringConvertible {
    case increment
    case triggerEffect

    var description: String {
        return rawValue
    }
}

private enum Effect: String, CustomStringConvertible, Equatable {
    case testEffect

    var description: String {
        return rawValue
    }
}

class NonReentrancyTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("MobiusLoop") {
            var loop: MobiusLoop<Model, Event, Effect>!
            var messages: [String]!
            var handleEffect: ((Effect, EffectCallback<Event>) -> Void)!

            func log(_ message: String) {
                messages.append(message)
            }

            beforeEach {
                messages = []

                let update = Update<Model, Event, Effect> { model, event in
                    log("update enter - model: \(model) event: \(event)")
                    defer {
                        log("update exit - model: \(model) event: \(event)")
                    }

                    switch event {
                    case .increment:
                        return .next(model + 1)
                    case .triggerEffect:
                        return .dispatchEffects([.testEffect])
                    }
                }

                let testEffectHandler: TestEffectHandler<Effect, Event> = {
                    handleEffect($0, $1)
                    return AnonymousDisposable {}
                }

                let effectConnectable = EffectRouter<Effect, Event>()
                    .routeEffects(equalTo: .testEffect).to(testEffectHandler)
                    .asConnectable

                loop = Mobius.loop(update: update, effectHandler: effectConnectable)
                    .start(from: 0)
            }

            sharedExamples("non-reentrant") {
                it("does not run update before the effect handler completes") {
                    loop.dispatchEvent(.increment)
                    loop.dispatchEvent(.increment)
                    loop.dispatchEvent(.triggerEffect)

                    // Despite the randomization in WorkBag, we must have two increments, one trigger, then two
                    // increments, with no overlap. The last two increments can be run in either order, but the
                    // effect is the same.
                    let expectedMessages = [
                        "update enter - model: 0 event: increment",
                        "update exit - model: 0 event: increment",
                        "update enter - model: 1 event: increment",
                        "update exit - model: 1 event: increment",
                        "update enter - model: 2 event: triggerEffect",
                        "update exit - model: 2 event: triggerEffect",
                        "handle enter - effect: testEffect",
                        "handle exit - effect: testEffect",
                        "update enter - model: 2 event: increment",
                        "update exit - model: 2 event: increment",
                        "update enter - model: 3 event: increment",
                        "update exit - model: 3 event: increment",
                    ]

                    expect(messages).to(equal(expectedMessages))
                }
            }

            context("when effect handler posts events through consumer") {
                beforeEach {
                    handleEffect = { effect, callback in
                        log("handle enter - effect: \(effect)")
                        defer {
                            log("handle exit - effect: \(effect)")
                        }

                        callback.send(.increment)
                        callback.send(.increment)
                        callback.end()
                    }
                }

                itBehavesLike("non-reentrant")
            }

            context("when effect handler dispatches effects directly") {
                // Like above, but calls loop.dispatchEvent. This is an antipattern, but is here to simulate the effect
                // of events coming in through the view connection of a MobiusController.
                beforeEach {
                    handleEffect = { effect, _ in
                        log("handle enter - effect: \(effect)")
                        defer {
                            log("handle exit - effect: \(effect)")
                        }

                        loop.dispatchEvent(.increment)
                        loop.dispatchEvent(.increment)
                    }
                }

                itBehavesLike("non-reentrant")
            }
        }
    }
}
