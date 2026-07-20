// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

private enum Effect: Equatable {
    // Effect 1 is handled
    case effect1
    // Effect 2 is not handled
    case effect2
}

private enum Event {
    case eventForEffect1
}

class EffectHandlerTests: QuickSpec {
    override class func spec() {
        describe("Handling effects with EffectHandler") {
            var effectHandler: AnyEffectHandler<Effect, Event>!
            var executeEffect: ((Effect) -> Void)!
            var receivedEvents: [Event]!

            beforeEach {
                effectHandler = AnyEffectHandler(handle: handleEffect)
                receivedEvents = []
                let callback = EffectCallback(
                    onSend: { event in
                        receivedEvents.append(event)
                    },
                    onEnd: {}
                )
                executeEffect = { effect in
                    _ = effectHandler.handle(effect, callback)
                }
            }

            context("When executing effects") {
                it("dispatches the expected event for an effect which can be handled") {
                    _ = executeEffect(.effect1)
                    expect(receivedEvents).to(equal([.eventForEffect1]))
                }

                it("dispatches no effects for events which cannot be handled") {
                    _ = executeEffect(.effect2)
                    expect(receivedEvents).to(beEmpty())
                }
            }
        }

        describe("Disposing EffectHandler") {
            it("calls the returned disposable when disposing") {
                var disposed = false
                let effectHandler = AnyEffectHandler<Effect, Event> { _, _ in
                    AnonymousDisposable {
                        disposed = true
                    }
                }
                let callback = EffectCallback<Event>(onSend: { _ in }, onEnd: {})
                effectHandler.handle(.effect1, callback).dispose()

                expect(disposed).to(beTrue())
            }
        }
    }
}

private func handleEffect(effect: Effect, callback: EffectCallback<Event>) -> Disposable {
    if effect == .effect1 {
        callback.send(.eventForEffect1)
    }
    callback.end()
    return AnonymousDisposable {}
}
