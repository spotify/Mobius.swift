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

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class MobiusLoopTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("MobiusLoop") {
            var builder: Mobius.Builder<String, String, String>!
            var loop: MobiusLoop<String, String, String>!
            var receivedModels: [String]!
            var effectHandler: SimpleTestConnectable!
            var queue: DispatchQueue!
            var modelObserver: Consumer<String>!

            beforeEach {
                receivedModels = []

                modelObserver = { receivedModels.append($0) }

                let update: Update<String, String, String> = { _, event in Next.next(event) }

                effectHandler = SimpleTestConnectable()

                queue = DispatchQueue.testQueue("test event queue")
                builder = Mobius.loop(update: update, effectHandler: effectHandler)
                    .withEventQueue(queue)
            }

            describe("addObservers") {
                beforeEach {
                    loop = builder.start(from: "the first model")
                }

                it("should emit the first model if you observe after start") {
                    loop.addObserver(modelObserver)

                    queue.waitForOutstandingTasks()
                    expect(receivedModels).to(equal(["the first model"]))
                }

                it("should be possible to unsubscribe an observer") {
                    let subscription = loop.addObserver(modelObserver)

                    loop.dispatchEvent("pre unsubscribe")
                    queue.waitForOutstandingTasks()

                    subscription.dispose()
                    loop.dispatchEvent("post unsubscribe")

                    queue.waitForOutstandingTasks()
                    expect(receivedModels).to(equal(["the first model", "pre unsubscribe"]))
                }

                it("should be possible to add multiple observers") {
                    var secondModelSet = [String]()

                    loop.addObserver(modelObserver)
                    let subscription = loop.addObserver({ model in secondModelSet.append(model) })

                    loop.dispatchEvent("floopity")
                    queue.waitForOutstandingTasks()

                    subscription.dispose()
                    loop.dispatchEvent("floopity floop")

                    queue.waitForOutstandingTasks()
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

                    queue.waitForOutstandingTasks()
                    expect(receivedModels).to(equal(["the beginning", "one", "two", "three"]))
                }

                it("should queue up events dispatched before start to support racy initialisations") {
                    loop = Mobius.loop(update: { model, event in .next(model + "-" + event) }, effectHandler: EagerEffectHandler())
                        .withEventQueue(queue)
                        .start(from: "the beginning")

                    queue.waitForOutstandingTasks()

                    loop.addObserver(modelObserver)

                    expect(receivedModels).to(equal(["the beginning-one-two-three"]))
                }
            }

            describe("most recent model") {
                it("should track the most recent model") {
                    loop = builder.start(from: "the first model")

                    expect(loop.latestModel).to(equal("the first model"))

                    loop.dispatchEvent("two")

                    queue.waitForOutstandingTasks()
                    expect(loop.latestModel).to(equal("two"))
                }
            }

            describe("dispose integration tests") {
                var errorThrown: Bool!
                beforeEach {
                    loop = builder.start(from: "disposable")
                    errorThrown = false
                    MobiusHooks.setErrorHandler({ _, _, _ in
                        errorThrown = true
                    })
                }

                afterEach {
                    MobiusHooks.setDefaultErrorHandler()
                }

                it("should dispose effect handler connection on dispose") {
                    loop.dispose()

                    expect(effectHandler.disposed).to(beTrue())
                }

                it("should disallow events post dispose") {
                    loop.dispose()
                    loop.dispatchEvent("nnooooo!!!")

                    expect(errorThrown).to(beTrue())
                }
            }

            describe("dispose dependencies") {
                var eventProcessor: TestEventProcessor<String, String, String>!
                var modelPublisher: ConnectablePublisher<String>!
                var disposable: ConnectablePublisher<String>!

                beforeEach {
                    eventProcessor = TestEventProcessor(
                        update: { _, _ in .noChange },
                        publisher: ConnectablePublisher(),
                        queue: DispatchQueue(label: "dispose test queue")
                    )
                    modelPublisher = ConnectablePublisher<String>()
                    disposable = ConnectablePublisher<String>()

                    loop = MobiusLoop(
                        eventProcessor: eventProcessor,
                        modelPublisher: modelPublisher,
                        disposable: disposable
                    )
                }

                it("should dispose all of the dependencies") {
                    loop.dispose()

                    expect(eventProcessor.disposed).to(equal(true))
                    expect(modelPublisher.isDisposed).to(equal(true))
                    expect(disposable.isDisposed).to(equal(true))
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

                it("should log startup") {
                    expect(logger.logMessages).toEventually(equal(["willInitiate(begin)", "didInitiate(begin, First<String, String>(model: \"begin\", effects: []))"]))
                }

                it("should log updates") {
                    logger.logMessages.removeAll()

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
                context("when a class corresponding to the ConnectableProtocol is used as effecthandler") {
                    beforeEach {
                        let update = { (_: String, _: String) -> Next<String, String> in
                            Next<String, String>.noChange
                        }

                        builder = Mobius.loop(update: update, effectHandler: TestConnectableProtocolImpl())
                    }

                    it("should produce a builder") {
                        expect(builder).toNot(beNil())
                    }
                }
            }

            describe("debug description") {
                let eventProcessorDebugDescription = "blah"
                beforeEach {
                    let publisher = ConnectablePublisher<String>()
                    let eventProcessor = TestEventProcessor<String, String, String>(
                        update: { _, _ in .noChange },
                        publisher: ConnectablePublisher<Next<String, String>>(),
                        queue: DispatchQueue(label: "dispose test queue")
                    )
                    eventProcessor.desiredDebugDescription = eventProcessorDebugDescription

                    loop = MobiusLoop(eventProcessor: eventProcessor, modelPublisher: publisher, disposable: publisher)
                }

                context("when not disposed") {
                    it("should describe the loop and the event processor") {
                        let description = String(describing: loop)
                        expect(description).to(equal("Optional(MobiusLoop<String, String, String> \(eventProcessorDebugDescription))"))
                    }
                }

                context("when disposed") {
                    it("should indicate that the loop is disposed") {
                        loop.dispose()
                        let description = String(describing: loop)
                        expect(description).to(equal("Optional(disposed loop!)"))
                    }
                }
            }
        }

        context("when configuring with an EffectHandler") {
            var loop: MobiusLoop<Int, Int, Int>!
            var isDisposed: Bool!
            var didReceiveEffect: Bool!
            beforeEach {
                isDisposed = false
                didReceiveEffect = false
                let effectHandler = EffectHandler<Int, Int>(
                    handle: { _, _ in
                        didReceiveEffect = true
                    },
                    disposable: AnonymousDisposable {
                        isDisposed = true
                    }
                )
                let path: (Int) -> Int? = { $0 }
                let effectConnectable = EffectRouter<Int, Int>()
                    .add(path: path, to: effectHandler)
                    .asConnectable
                let update = { (_: Int, _: Int) -> Next<Int, Int> in Next.dispatchEffects([1]) }
                loop = Mobius
                    .loop(update: update, effectHandler: effectConnectable)
                    .start(from: 0)
            }
            afterEach {
                loop.dispose()
            }

            it("should dispatch effects to the EffectHandler") {
                loop.dispatchEvent(1)
                expect(didReceiveEffect).toEventually(beTrue())
            }

            it("should dispose the EffectHandler when the loop is disposed") {
                loop.dispose()
                expect(isDisposed).toEventually(beTrue())
            }
        }
    }
}

private class EagerEffectHandler: Connectable {
    typealias InputType = String
    typealias OutputType = String

    func connect(_ consumer: @escaping Consumer<String>) -> Connection<String> {
        consumer("one")
        consumer("two")
        consumer("three")

        return RecordingTestConnectable().connect(consumer)
    }
}

private class TestEventProcessor<Model, Event, Effect>: EventProcessor<Model, Event, Effect> {
    var disposed = false
    override func dispose() {
        disposed = true
    }

    var desiredDebugDescription: String?
    public override var debugDescription: String {
        return desiredDebugDescription ?? ""
    }
}

private class TestConnectableProtocolImpl: Connectable {
    typealias InputType = String
    typealias OutputType = String

    func connect(_: @escaping (String) -> Void) -> Connection<String> {
        return Connection(acceptClosure: { _ in }, disposeClosure: {})
    }
}
