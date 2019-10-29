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
            var dispatchEffect: Consumer<OuterEffect>!
            var stopHandling: (() -> Void)!
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
                    canHandle: canHandle,
                    handle: handleEffect,
                    stopHandling: onDispose
                )
                let connection = effectHandler.connect { effect in
                    receivedEffects.append(effect)
                }
                dispatchEffect = connection.accept
                stopHandling = connection.dispose
            }
            afterEach {
                stopHandling()
            }

            context("`canHandle` unwraps effects with associated values") {
                it("unwraps and outputs the effect's associated value if it satisfies `canHandle`") {
                    dispatchEffect(.innerEffect(.effect1))

                    expect(receivedEffects).to(equal([.effect1]))
                }

                it("does not unwrap or output the effect's associated value if it does not satisfy `canHandle`") {
                    dispatchEffect(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([]))
                }

                it("unwraps and outputs only the effects which satisfy `canHandle`") {
                    dispatchEffect(.innerEffect(.effect1))
                    dispatchEffect(.innerEffect(.effect2))
                    dispatchEffect(.innerEffect(.effect1))
                    dispatchEffect(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([.effect1, .effect1]))
                }
            }

            context("`stopHandling`") {
                it("The `stopHandling` function is called when the connection is disposed") {
                    stopHandling()

                    expect(isDisposed).to(beTrue())
                }

                it("`stopHandling` is idempotent") {
                    stopHandling()
                    stopHandling()
                    stopHandling()
                    expect(isDisposed).to(beTrue())
                }

                it("crashes if events are dispatched after `stopHandling` is called") {
                    stopHandling()
                    expect({
                        dispatchEffect(.innerEffect(.effect1))
                    }()).to(throwAssertion())
                }
            }

            context("reconnecting after `stopHandling` is called") {
                it("is possible to connect again after the effect handler has been disposed") {
                    dispatchEffect(.innerEffect(.effect1))
                    stopHandling()
                    let connection = effectHandler.connect { effect in
                        receivedEffects.append(effect)
                    }
                    connection.accept(.innerEffect(.effect1))
                    connection.accept(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([.effect1, .effect1]))
                    connection.dispose()
                }
            }

            context("connecting multiple times") {
                it("should crash if the effect handler is connected to multiple times without disposing in between") {
                    expect({
                        _ = effectHandler.connect { _ in }
                    }()).to(throwAssertion())
                }
            }
        }
    }
}

private func canHandle(effect: OuterEffect) -> HandleEffect<InnerEffect> {
    switch effect {
    case .innerEffect(let effect):
        if effect == .effect1 {
            return .handle(effect)
        } else {
            return .ignore
        }
    }
}
