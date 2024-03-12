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

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class MobiusLoopTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("MobiusLoop") {
            var builder: Mobius.Builder<String, String, String>!
            var loop: MobiusLoop<String, String, String>!
            var receivedModels: [String]!
            var effectHandler: RecordingTestConnectable!
            var modelObserver: Consumer<String>!

            beforeEach {
                receivedModels = []

                modelObserver = { receivedModels.append($0) }

                let update = Update<String, String, String> { _, event in Next.next(event) }

                effectHandler = RecordingTestConnectable()

                builder = Mobius.loop(update: update, effectHandler: effectHandler)
            }

            describe("addObservers") {
                beforeEach {
                    loop = builder.start(from: "the first model")
                }

                it("should emit the first model if you observe after start") {
                    loop.addObserver(modelObserver)

                    expect(receivedModels).to(equal(["the first model"]))
                }

                it("should be possible to unsubscribe an observer") {
                    let subscription = loop.addObserver(modelObserver)

                    loop.dispatchEvent("pre unsubscribe")

                    subscription.dispose()
                    loop.dispatchEvent("post unsubscribe")

                    expect(receivedModels).to(equal(["the first model", "pre unsubscribe"]))
                }

                it("should be possible to add multiple observers") {
                    var secondModelSet = [String]()

                    loop.addObserver(modelObserver)
                    let subscription = loop.addObserver({ model in secondModelSet.append(model) })

                    loop.dispatchEvent("floopity")

                    subscription.dispose()
                    loop.dispatchEvent("floopity floop")

                    expect(receivedModels).to(equal(["the first model", "floopity", "floopity floop"]))
                    expect(secondModelSet).to(equal(["the first model", "floopity"]))
                }
            }

            describe("event dispatch") {
                it("should be possible to dispatch events after start") {
                    loop = builder.start(from: "the beginning")
                    loop.addObserver(modelObserver)

                    loop.dispatchEvent("one")
                    loop.dispatchEvent("two")
                    loop.dispatchEvent("three")

                    expect(receivedModels).to(equal(["the beginning", "one", "two", "three"]))
                }

                it("should queue up events dispatched before start to support racy initializations") {
                    loop = Mobius.loop(update: Update { model, event in .next(model + "-" + event) }, effectHandler: EagerEffectHandler())
                        .start(from: "the beginning")

                    loop.addObserver(modelObserver)

                    // receivedModels contains the concatenation of received events, but the order is randomized, so
                    // we need to turn it into a collection
                    let components = receivedModels.first!.split(separator: "-")
                    expect(components.first).to(equal("the beginning"))
                    expect(components.sorted()).to(equal(["one", "the beginning", "three", "two"]))
                }
            }

            describe("most recent model") {
                it("should track the most recent model") {
                    loop = builder.start(from: "the first model")

                    expect(loop.latestModel).to(equal("the first model"))

                    loop.dispatchEvent("two")

                    expect(loop.latestModel).to(equal("two"))
                }
            }

            describe("dispose integration tests") {
                beforeEach {
                    loop = builder.start(from: "disposable")
                }

                it("should allow disposing immediately after an effect") {
                    loop.dispatchEvent("event")
                    loop.dispose()
                }

                it("should dispose effect handler connection on dispose") {
                    loop.dispose()

                    expect(effectHandler.disposed).to(beTrue())
                }

                it("should disallow events post dispose") {
                    loop.dispose()
                    expect(loop.dispatchEvent("nnooooo!!!")).to(raiseError())
                }
            }

            describe("logging") {
                var logger: TestMobiusLogger!

                beforeEach {
                    logger = TestMobiusLogger()
                    loop = builder
                        .withLogger(logger)
                        .start(from: "begin")
                }

                it("should log updates") {
                    logger.clear()

                    loop.dispatchEvent("hey")

                    expect(logger.logMessages).toEventually(equal(["willUpdate(begin, hey)", "didUpdate(begin, hey, (\"hey\", []))"]))
                }
            }

            context("deinit") {
                beforeEach {
                    loop = builder.start(from: "the first model")
                }

                context("when the loop has been deallocated") {
                    it("should dispose") {
                        loop = nil
                        expect(effectHandler.disposed).to(beTrue()) // Indirect test. Consider refactoring
                    }
                }
            }

            describe("when creating a builder") {
                context("when a class corresponding to the ConnectableProtocol is used as effect handler") {
                    beforeEach {
                        let update = Update { (_: String, _: String) -> Next<String, String> in
                            Next<String, String>.noChange
                        }

                        builder = Mobius.loop(update: update, effectHandler: SimpleTestConnectable())
                    }

                    it("should produce a builder") {
                        expect(builder).toNot(beNil())
                    }
                }
            }

            describe("debug description") {
                beforeEach {
                    loop = Mobius.loop(update: { _, _ in .noChange }, effectHandler: SimpleTestConnectable())
                        .start(from: "hello")
                }

                context("when not disposed") {
                    it("should describe the loop and the model") {
                        let description = String(describing: loop)
                        expect(description).to(equal(#"Optional(MobiusLoop<String, String, String>{ "hello" })"#))
                    }
                }

                context("when disposed") {
                    it("should indicate that the loop is disposed") {
                        loop.dispose()
                        let description = String(describing: loop)
                        expect(description).to(equal("Optional(disposed MobiusLoop<String, String, String>!)"))
                    }
                }
            }

            context("when starting with effects") {
                beforeEach {
                    loop = builder.start(from: "S", effects: ["F1", "F2"])
                }

                it("should immediately execute the specified events") {
                    expect(effectHandler.recorder.items).to(contain("F1", "F2"))
                }
            }
        }

        context("when configuring with an EffectHandler") {
            var loop: MobiusLoop<Int, Int, Int>!
            // swiftlint:disable:next quick_discouraged_call
            let disposed = Synchronized<Bool>(value: false)
            // swiftlint:disable:next quick_discouraged_call
            let didReceiveEffect = Synchronized<Bool>(value: false)
            beforeEach {
                disposed.value = false
                didReceiveEffect.value = false
                let effectHandler = AnyEffectHandler<Int, Int> { _, _ in
                    didReceiveEffect.value = true
                    return AnonymousDisposable {
                        disposed.value = true
                    }
                }
                let parameterExtractor: (Int) -> Int? = { $0 }
                let effectConnectable = EffectRouter<Int, Int>()
                    .routeEffects(withParameters: parameterExtractor).to(effectHandler)
                    .asConnectable
                let update = Update { (_: Int, _: Int) -> Next<Int, Int> in Next.dispatchEffects([1]) }
                loop = Mobius
                    .loop(update: update, effectHandler: effectConnectable)
                    .start(from: 0)
            }
            afterEach {
                loop.dispose()
            }

            it("should dispatch effects to the EffectHandler") {
                loop.dispatchEvent(1)
                expect(didReceiveEffect.value).toEventually(beTrue())
            }

            it("should dispose the EffectHandler when the loop is disposed") {
                loop.dispatchEvent(1)
                loop.dispose()
                expect(disposed.value).toEventually(beTrue())
            }
        }
    }
}

private class EagerEffectHandler: Connectable {
    func connect(_ consumer: @escaping Consumer<String>) -> Connection<String> {
        consumer("one")
        consumer("two")
        consumer("three")

        return RecordingTestConnectable().connect(consumer)
    }
}
