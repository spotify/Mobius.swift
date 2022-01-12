// Copyright 2019-2022 Spotify AB.
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
import Nimble
import Quick

private typealias Effect = String
private typealias Event = String

class AnyEffectHandlerTests: QuickSpec {
    // swiftlint:disable function_body_length
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
