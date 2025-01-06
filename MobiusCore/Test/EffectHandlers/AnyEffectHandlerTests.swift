// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore
import Nimble
import Quick

private typealias Effect = String
private typealias Event = String

class AnyEffectHandlerTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("AnyEffectHandler") {
            var effectHandler: AnyEffectHandler<Effect, Event>!
            var receivedEvents: [Event]!

            beforeEach {
                receivedEvents = []
            }

            sharedExamples("expected AnyEffectHandler behaviour") {
                it("invokes send and end") {
                    let callback = EffectCallback(
                        onSend: { receivedEvents.append("e-" + $0) },
                        onEnd: { receivedEvents.append("end") }
                    )

                    let disposable = effectHandler.handle("f1", callback)
                    disposable.dispose()

                    expect(receivedEvents).to(equal(["e-f1", "end"]))
                }
            }

            context("when initialized with a closure") {
                beforeEach {
                    effectHandler = AnyEffectHandler { effect, callback in
                        callback.send(effect)
                        return AnonymousDisposable {
                            callback.end()
                        }
                    }
                }

                itBehavesLike("expected AnyEffectHandler behaviour")
            }

            context("when initialized with wrapped effect handler") {
                beforeEach {
                    let wrapped = TestEffectHandler()
                    effectHandler = AnyEffectHandler(handler: wrapped)
                }

                itBehavesLike("expected AnyEffectHandler behaviour")
            }

            context("when initialized with doubly wrapped effect handler") {
                beforeEach {
                    let wrapped = TestEffectHandler()
                    let inner = AnyEffectHandler(handler: wrapped)
                    effectHandler = AnyEffectHandler(handler: inner)
                }

                itBehavesLike("expected AnyEffectHandler behaviour")
            }
        }
    }
}

private struct TestEffectHandler: EffectHandler {
    func handle(_ effect: Effect, _ callback: EffectCallback<Event>) -> Disposable {
        callback.send(effect)
        return AnonymousDisposable {
            callback.end()
        }
    }
}
