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

import MobiusCore
import Nimble
import Quick

private enum Effect {
    case payload1(Int)
    case payload2(String)
}

class EffectHandlerCompositionTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("Composing effect handlers") {
            context("When composing effect handlers") {

                var effectHandler1ReceivedPayload: [Int]!
                var effectHandler2ReceivedPayload: [String]!
                var composedEffectHandler: EffectHandler<Effect, Int>!

                beforeEach {
                    effectHandler1ReceivedPayload = []
                    effectHandler2ReceivedPayload = []
                    let effectHandler1 = EffectHandler<Effect, Int>(
                        canHandle: { effect in
                            switch effect {
                            case .payload1(let payload): return payload
                            default: return nil
                            }
                        } ,
                        handle: { payload, _ in
                            effectHandler1ReceivedPayload.append(payload)
                        }
                    )
                    let effectHandler2 = EffectHandler<Effect, Int>(
                        canHandle: { effect in
                            switch effect {
                            case .payload2(let payload): return payload
                            default: return nil
                            }
                        } ,
                        handle: { payload, _ in
                            effectHandler2ReceivedPayload.append(payload)
                        }
                    )
                    composedEffectHandler = EffectHandler(
                        effectHandler1,
                        effectHandler2
                    )
                }

                it("Should dispatch effects to the expected EffectHandler with the expected payload") {
                    let connection = composedEffectHandler.connect { _ in }

                    connection.accept(.payload1(5))
                    expect(effectHandler1ReceivedPayload).to(equal([5]))
                    expect(effectHandler2ReceivedPayload).to(equal([]))

                    connection.accept(.payload2("test"))
                    expect(effectHandler1ReceivedPayload).to(equal([5]))
                    expect(effectHandler2ReceivedPayload).to(equal(["test"]))

                    connection.dispose()
                }
            }

            context("When disposing composed effect handlers") {
                var effectHandler1Disposed: Bool!
                var effectHandler2Disposed: Bool!
                var composedEffectHandler: EffectHandler<Int, Int>!

                beforeEach {
                    effectHandler1Disposed = false
                    effectHandler2Disposed = false
                    let effectHandler1 = EffectHandler<Int, Int>(
                        handledEffect: 1,
                        handle: { _, _ in },
                        stopHandling: {
                            effectHandler1Disposed = true
                        }
                    )
                    let effectHandler2 = EffectHandler<Int, Int>(
                        handledEffect: 1,
                        handle: { _, _ in },
                        stopHandling: {
                            effectHandler2Disposed = true
                        }
                    )
                    composedEffectHandler = EffectHandler(
                        effectHandler1,
                        effectHandler2
                    )
                }

                it("Should dispose all the effect handlers used in the composition") {
                    composedEffectHandler
                        .connect { _ in }
                        .dispose()

                    expect(effectHandler1Disposed && effectHandler2Disposed).to(beTrue())
                }
            }

            context("When multiple composed effect handlers handle the same effect") {
                var composedEffectHandler: EffectHandler<Int, Int>!

                beforeEach {
                    let effectHandler1 = EffectHandler<Int, Int>(
                        handledEffect: 1,
                        handle: { _, _ in }
                    )
                    let effectHandler2 = EffectHandler<Int, Int>(
                        handledEffect: 1,
                        handle: { _, _ in }
                    )
                    composedEffectHandler = EffectHandler(
                        effectHandler1,
                        effectHandler2
                    )
                }

                it("Should crash when the relevant effect is emitted") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }
                    let connection = composedEffectHandler
                        .connect { _ in }
                    expect(didCrash).to(beFalse())

                    connection.accept(1)
                    expect(didCrash).to(beTrue())

                    connection.dispose()

                }
            }
        }
    }
}
