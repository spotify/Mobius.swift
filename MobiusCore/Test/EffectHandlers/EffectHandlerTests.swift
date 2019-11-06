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

enum InnerEffect: Equatable {
    case effect1
    case effect2
}

enum OuterEffect: Equatable {
    case innerEffect(InnerEffect)
}

// swiftlint:disable type_body_length file_length

class EffectHandlerTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("EffectHandler tests") {
            var receivedEffects: [InnerEffect]!
            var executeSideEffectFor: Consumer<OuterEffect>!
            var dispose: (() -> Void)!
            var isDisposed: Bool!
            var effectHandler: EffectHandler<OuterEffect, InnerEffect>!
            func onDispose() {
                isDisposed = true
            }
            func handleEffect(effect: InnerEffect, dispatch: @escaping Consumer<InnerEffect>) {
                dispatch(effect)
            }
            beforeEach {
                isDisposed = false
                receivedEffects = []
                effectHandler = EffectHandler<OuterEffect, InnerEffect>(
                    payloadFor: payloadFor,
                    handlePayload: handleEffect,
                    stopHandling: onDispose
                )
                let connection = EffectExecutor(effectHandler: effectHandler) { effect in
                    receivedEffects.append(effect)
                }
                executeSideEffectFor = { connection.execute($0) }
                dispose = connection.dispose
            }
            afterEach {
                dispose()
            }

            context("`payloadFor` unwraps effects with associated values") {
                it("unwraps and outputs the effect's associated value if it satisfies `payloadFor`") {
                    executeSideEffectFor(.innerEffect(.effect1))

                    expect(receivedEffects).to(equal([.effect1]))
                }

                it("does not unwrap or output the effect's associated value if it does not satisfy `payloadFor`") {
                    executeSideEffectFor(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([]))
                }

                it("unwraps and outputs only the effects which satisfy `payloadFor`") {
                    executeSideEffectFor(.innerEffect(.effect1))
                    executeSideEffectFor(.innerEffect(.effect2))
                    executeSideEffectFor(.innerEffect(.effect1))
                    executeSideEffectFor(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([.effect1, .effect1]))
                }
            }

            context("`dispose`") {
                it("The `stopHandling` function is called when the connection is disposed") {
                    dispose()

                    expect(isDisposed).to(beTrue())
                }

                it("`dispose` is idempotent") {
                    dispose()
                    dispose()
                    dispose()
                    expect(isDisposed).to(beTrue())
                }

                it("crashes if events are dispatched after `dispose` is called") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }

                    dispose()
                    executeSideEffectFor(.innerEffect(.effect1))
                    expect(didCrash).to(beTrue())
                }
            }

            context("reconnecting after `dispose` is called") {
                it("is possible to connect again after the effect handler has been disposed") {
                    executeSideEffectFor(.innerEffect(.effect1))
                    dispose()
                    let connection = EffectExecutor(effectHandler: effectHandler) { effect in
                        receivedEffects.append(effect)
                    }
                    _ = connection.execute(.innerEffect(.effect1))
                    _ = connection.execute(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([.effect1, .effect1]))
                    connection.dispose()
                }
            }

            context("connecting multiple times") {
                it("should not crash") {
                    var didCrash = false
                    MobiusHooks.setErrorHandler { _, _, _ in
                        didCrash = true
                    }

                    let connection = EffectExecutor(effectHandler: effectHandler)  { _ in }
                    expect(didCrash).to(beFalse())
                    connection.dispose()
                }

                it("should support multiple independent connections without interference") {
                    var newConnectionWasCalled = false
                    let newConnection = EffectExecutor(effectHandler: effectHandler) { _ in
                        newConnectionWasCalled = true
                    }
                    _ = newConnection.execute(.innerEffect(.effect1))
                    expect(newConnectionWasCalled).to(beTrue())
                    expect(receivedEffects).to(equal([]))
                    newConnection.dispose()
                }

                it("should be resilient to any of the independent connections being torn down") {
                    var newConnectionWasCalled = false
                    let newConnection = EffectExecutor(effectHandler: effectHandler) { _ in
                        newConnectionWasCalled = true
                    }
                    dispose()
                    expect(isDisposed).to(beTrue())

                    _ = newConnection.execute(.innerEffect(.effect1))
                    expect(newConnectionWasCalled).to(beTrue())

                    newConnection.dispose()
                }
            }
        }
    }
}

private func payloadFor(effect: OuterEffect) -> InnerEffect? {
    switch effect {
    case .innerEffect(let effect):
        return effect == .effect1
            ? effect
            : nil
    }
}
