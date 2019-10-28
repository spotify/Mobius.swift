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

// swiftlint:disable type_body_length file_length

class EffectRouterBuilderTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("Legacy EffectRouterBuilder") {
            var sut: EffectRouterBuilder<String, String>!

            var output: String?
            let outputHandler: Consumer<String> = { (string: String) in
                output = string
            }

            beforeEach {
                sut = EffectRouterBuilder<String, String>()
            }

            context("when adding filtered effect handler") {
                var effectHandlerForTriggeredEffect: TestFilteredConnectable!
                var effectHandlerForUnusedEffect: TestFilteredConnectable!

                let sentEffect = "sent"
                let effectNotSent = "do not send"

                beforeEach {
                    effectHandlerForTriggeredEffect = TestFilteredConnectable()
                    effectHandlerForTriggeredEffect.effectToAccept = sentEffect
                    sut = sut.addConnectable(effectHandlerForTriggeredEffect)

                    effectHandlerForUnusedEffect = TestFilteredConnectable()
                    effectHandlerForUnusedEffect.effectToAccept = effectNotSent
                    sut = sut.addConnectable(effectHandlerForUnusedEffect)
                }

                context("when connecting to an output handler") {
                    let expectedOutput = "some ouput string"
                    beforeEach {
                        _ = sut.build().connect(outputHandler)
                        effectHandlerForTriggeredEffect.outputHandler?(expectedOutput)
                    }

                    it("that output handler should be passed to the effect handler") {
                        expect(output).to(equal(expectedOutput))
                    }
                }

                context("when receiving an effect") {
                    beforeEach {
                        sut.build().connect(outputHandler).accept(sentEffect)
                    }

                    it("should call the effect handler handling that effect") {
                        expect(effectHandlerForTriggeredEffect.receivedString).to(equal(sentEffect))
                    }

                    it("should not call the effect handler ignoring that effect") {
                        expect(effectHandlerForUnusedEffect.receivedString).to(beNil())
                    }
                }
            }

            context("when adding more than one filtered effect handler filtering on the same effect") {
                var effectHandler1: TestFilteredConnectable!
                var effectHandler2: TestFilteredConnectable!

                let effect = "Effect"

                beforeEach {
                    effectHandler1 = TestFilteredConnectable()
                    effectHandler1.effectToAccept = effect
                    sut = sut.addConnectable(effectHandler1)

                    effectHandler2 = TestFilteredConnectable()
                    effectHandler2.effectToAccept = effect
                    sut = sut.addConnectable(effectHandler2)
                }

                context("when that effect is dispatched") {
                    var mobiusError: String?
                    beforeEach {
                        MobiusHooks.setErrorHandler({ (error: String, _, _) in
                            mobiusError = error
                        })

                        sut.build().connect(outputHandler).accept(effect)
                    }

                    it("should generate an error in the error handler") {
                        expect(mobiusError).toNot(beNil())
                    }
                }
            }

            context("when adding no effect handler for an effect") {
                context("when that effect is dispatched") {
                    var mobiusError: String?

                    let effect = "Effect"
                    beforeEach {
                        MobiusHooks.setErrorHandler({ (error: String, _, _) in
                            mobiusError = error
                        })

                        sut.build().connect(outputHandler).accept(effect)
                    }

                    it("should generate an error in the error handler") {
                        expect(mobiusError).toNot(beNil())
                    }
                }
            }

            context("when adding a function for a certain effect") {
                var eventToReturn: String?
                var effectReceived: String?
                let function = { (effect: String) -> String? in
                    effectReceived = effect
                    return eventToReturn
                }

                let acceptedEffect = "some effect"
                let predicate = { (effect: String) in
                    effect == acceptedEffect
                }

                var output: String?
                let outputHandler = { (string: String) in
                    output = string
                }

                beforeEach {
                    eventToReturn = nil
                    effectReceived = nil
                    output = nil
                    sut = sut
                        .addFunction(function, predicate: predicate)
                        // Fallback for unhandled effects
                        .addFunction({ _ in nil }, predicate: { input in !predicate(input) })
                }

                context("when the effect is dispatched") {
                    var connection: Connection<String>!
                    beforeEach {
                        connection = sut.build().connect(outputHandler)
                    }

                    it("should call the function with that effect") {
                        connection.accept(acceptedEffect)
                        expect(effectReceived).to(equal(acceptedEffect))
                    }

                    context("and the function produces an event") {
                        it("should call the ouput handler with the event") {
                            eventToReturn = "some event"
                            connection.accept(acceptedEffect)
                            expect(output).to(equal(eventToReturn))
                        }
                    }

                    context("and the function does not produce an event") {
                        it("should not call the output handler") {
                            connection.accept(acceptedEffect)
                            expect(output).to(beNil())
                        }
                    }
                }

                context("when another effect is received") {
                    beforeEach {
                        sut.build().connect(outputHandler).accept("random effect")
                    }
                    it("should not call the function with that effect") {
                        expect(effectReceived).to(beNil())
                    }
                }
            }

            context("when handling effects using a Consumer") {
                var handler: Connection<String>!
                var testConsumer: TestConsumer!
                class TestConsumer: ConsumerWithPredicate {
                    let acceptableString = "Acceptable"
                    typealias Effect = String
                    var acceptCount = 0

                    func canAccept(_ effect: String) -> Bool {
                        return effect == acceptableString
                    }

                    func accept(_ effect: String) {
                        acceptCount += 1
                    }
                }

                beforeEach {
                    testConsumer = TestConsumer()
                    handler = sut
                        .addConsumer(testConsumer)
                        // fallback for unhandled effects
                        .addFunction({ _ in nil }, predicate: { str in testConsumer.acceptableString != str })
                        .build()
                        .connect(outputHandler)
                }

                it("should call the consumer when an effect matches its predicate") {
                    handler.accept(testConsumer.acceptableString)
                    expect(testConsumer.acceptCount).to(equal(1))
                }

                it("should not call the consumer when an effect does not match its predicate") {
                    handler.accept(testConsumer.acceptableString + "1")
                    handler.accept(testConsumer.acceptableString + "2")
                    handler.accept(testConsumer.acceptableString + "3")
                    expect(testConsumer.acceptCount).to(equal(0))
                }

                it("should be resilient to a mix of effects which match (and don't match) the predicate") {
                    handler.accept(testConsumer.acceptableString + "1")
                    expect(testConsumer.acceptCount).to(equal(0))
                    handler.accept(testConsumer.acceptableString)
                    expect(testConsumer.acceptCount).to(equal(1))
                    handler.accept(testConsumer.acceptableString + "2")
                    handler.accept(testConsumer.acceptableString + "3")
                    expect(testConsumer.acceptCount).to(equal(1))
                    handler.accept(testConsumer.acceptableString)
                    expect(testConsumer.acceptCount).to(equal(2))
                }
            }

            context("when using an ActionWithPredicate") {
                var testAction: TestAction!
                var handler: Connection<String>!
                class TestAction: ActionWithPredicate {
                    typealias Effect = String

                    static let acceptableString = "Acceptable"
                    var runCount = 0

                    func canAccept(_ effect: String) -> Bool {
                        return effect == TestAction.acceptableString
                    }

                    func run() {
                        runCount += 1
                    }
                }

                beforeEach {
                    testAction = TestAction()
                    handler = sut
                        .addAction(testAction)
                        // Fallback for unhandled effects
                        .addFunction({ _ in nil }, predicate: { eff in eff != TestAction.acceptableString })
                        .build()
                        .connect(outputHandler)
                }

                it("should run when the effect matches the predicate") {
                    handler.accept(TestAction.acceptableString)
                    expect(testAction.runCount).to(equal(1))
                }

                it("should not run when the effect does not match the predicate") {
                    handler.accept(TestAction.acceptableString + "1")
                    expect(testAction.runCount).to(equal(0))
                }

                it("should run only when the effect matches the predicate") {
                    handler.accept(TestAction.acceptableString + "1")
                    handler.accept(TestAction.acceptableString + "1")
                    expect(testAction.runCount).to(equal(0))
                    handler.accept(TestAction.acceptableString)
                    handler.accept(TestAction.acceptableString)
                    expect(testAction.runCount).to(equal(2))
                }
            }

            context("when using a FunctionWithPredicate") {
                let fallback = "fallback"
                var handler: Connection<String>!

                class TestFunction: FunctionWithPredicate {
                    typealias Event = String
                    typealias Effect = String
                    static let acceptableEffect = "Acceptable"
                    static let responseEvent = "Response"
                    func canAccept(_ effect: String) -> Bool {
                        return effect == TestFunction.acceptableEffect
                    }

                    func apply(_ effect: String) -> String {
                        return effect + TestFunction.responseEvent
                    }
                }

                beforeEach {
                    let testFunction = TestFunction()
                    handler = sut
                        .addFunction(testFunction)
                        // Fallback for unhandled effects
                        .addFunction({ _ in fallback }, predicate: { eff in eff != TestFunction.acceptableEffect })
                        .build()
                        .connect(outputHandler)
                }

                it("should call the function when the effect matches its predicate") {
                    handler.accept(TestFunction.acceptableEffect)
                    expect(output).to(equal(TestFunction.acceptableEffect + TestFunction.responseEvent))
                }

                it("should not call the function when the effect does not match its predicate") {
                    handler.accept(TestFunction.acceptableEffect + "not")
                    expect(output).to(equal(fallback))
                }
            }

            context("when running on a specific dispatch queue") {
                class TestFunction: FunctionWithPredicate {
                    typealias Event = String
                    typealias Effect = String
                    func canAccept(_ effect: String) -> Bool { return true }
                    func apply(_ effect: String) -> String {
                        // label of the current dispatch queue
                        return String(validatingUTF8: __dispatch_queue_get_label(nil))!
                    }
                }

                it("should dispatch on the test queue") {
                    let testQueue = DispatchQueue(label: "testqueuelabel")
                    sut
                        .addFunction(TestFunction(), queue: testQueue)
                        .build()
                        .connect(outputHandler)
                        .accept("test")
                    expect(output).toEventually(equal(testQueue.label))
                }
            }

            context("when disposing of the effect handler produced by the composite connectable") {
                var effectHandlers: [TestFilteredConnectable]!

                beforeEach {
                    effectHandlers = []
                    for index in 1...4 {
                        let effectHandler = TestFilteredConnectable()
                        effectHandler.effectToAccept = "\(index)"
                        sut = sut.addConnectable(effectHandler)
                        effectHandlers.append(effectHandler)
                    }
                }

                it("should dispose all of the added effect handlers") {
                    sut.build().connect(outputHandler).dispose()

                    effectHandlers.forEach({ (effectHandler: TestFilteredConnectable) in
                        expect(effectHandler.disposed).to(beTrue())
                    })
                }
            }
        }

        describe("EffectRouterBuilder") {
            context("when adding an `EffectHandler`") {
                var connection: Connection<Int>!
                var receivedEvents: [Int]!

                beforeEach {
                    // An effect handler which only accepts the number 1. When it gets a 1, it emits a 1 as its event.
                    let effectHandler1 = EffectHandler.makeEffectHandler(acceptsEffect: 1, handleEffect: handleEffect)
                    // An effect handler which only accepts the number 2. When it gets a 2, it emits a 2 as its event.
                    let effectHandler2 = EffectHandler.makeEffectHandler(acceptsEffect: 2, handleEffect: handleEffect)
                    connection = EffectRouterBuilder()
                        .addEffectHandler(effectHandler1)
                        .addEffectHandler(effectHandler2)
                        .build()
                        .connect { event in
                            receivedEvents.append(event)
                        }
                    receivedEvents = []
                }
                afterEach {
                    connection.dispose()
                }

                it("dispatches effects which satisfy the effect handler's `canAccept` function") {
                    connection.accept(1)
                    connection.accept(2)
                    expect(receivedEvents).to(equal([1, 2]))
                }

                it("crashes if an effect which no EffectHandler can handle is emitted") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }

                    connection.accept(3)

                    expect(didCrash).to(beTrue())
                }
            }

            context("when multiple `EffectHandler`s handle the same effect") {
                var connection: Connection<Int>!
                beforeEach {
                    let effectHandler1 = EffectHandler.makeEffectHandler(acceptsEffect: 1, handleEffect: handleEffect)
                    let effectHandler2 = EffectHandler.makeEffectHandler(acceptsEffect: 1, handleEffect: handleEffect)
                    connection = EffectRouterBuilder()
                        .addEffectHandler(effectHandler1)
                        .addEffectHandler(effectHandler2)
                        .build()
                        .connect { _ in }
                }
                afterEach {
                    connection.dispose()
                }

                it("should crash") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }
                    connection.accept(1)
                    expect(didCrash).to(beTrue())
                }
            }
        }
    }
}

private func handleEffect(effect: Int, dispatch: @escaping Consumer<Int>) {
    dispatch(effect)
}

private class TestFilteredConnectable: Connectable, EffectPredicate {
    typealias InputType = String
    typealias OutputType = String

    var outputHandler: Consumer<String>?
    var queueLabel: String?
    var receivedString: String?
    var disposed = false
    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        outputHandler = consumer
        return Connection<String>(
            acceptClosure: { string in
                self.receivedString = string
                self.queueLabel = getLabelForCurrentQueue()
            },
            disposeClosure: {
                self.disposed = true
            }
        )
    }

    var effectToAccept: String?
    func canAccept(_ string: String) -> Bool {
        let filterString = effectToAccept ?? ""
        return string == filterString
    }
}

private func getLabelForCurrentQueue() -> String? {
    let name = __dispatch_queue_get_label(nil)
    return String(cString: name, encoding: .utf8)
}
