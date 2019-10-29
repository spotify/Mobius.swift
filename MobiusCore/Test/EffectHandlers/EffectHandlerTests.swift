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
            var dispose: (() -> Void)!
            var isDisposed: Bool!
            func onDispose() {
                isDisposed = true
            }
            func handleEffect(effect: InnerEffect, dispatch: @escaping Consumer<InnerEffect>) {
                dispatch(effect)
            }
            let effectHandler = EffectHandler<OuterEffect, InnerEffect>(
                canAccept: canAccept,
                handleEffect: handleEffect,
                onDispose: onDispose
            )
            beforeEach {
                isDisposed = false
                receivedEffects = []
                let connection = effectHandler.connect { effect in
                    receivedEffects.append(effect)
                }
                dispatchEffect = connection.accept
                dispose = connection.dispose
            }
            afterEach {
                dispose()
            }

            context("`canAccept` unwraps effects with associated values") {
                it("unwraps and outputs the effect's associated value if it satisfies `canAccept`") {
                    dispatchEffect(.innerEffect(.effect1))

                    expect(receivedEffects).to(equal([.effect1]))
                }

                it("does not unwrap or output the effect's associated value if it does not satisfy `canAccept`") {
                    dispatchEffect(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([]))
                }

                it("unwraps and outputs only the effects which satisfy `canAccept`") {
                    dispatchEffect(.innerEffect(.effect1))
                    dispatchEffect(.innerEffect(.effect2))
                    dispatchEffect(.innerEffect(.effect1))
                    dispatchEffect(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([.effect1, .effect1]))
                }
            }

            context("`dispose`") {
                it("The `onDispose` function is called when the connection is disposed") {
                    dispose()

                    expect(isDisposed).to(beTrue())
                }

                it("`dispose` is idempotent") {
                    dispose()
                    dispose()
                    dispose()
                    expect(isDisposed).to(beTrue())
                }

                it("does not emit events after `dispose`") {
                    dispose()
                    dispatchEffect(.innerEffect(.effect1))
                    dispatchEffect(.innerEffect(.effect2))

                    expect(receivedEffects).to(equal([]))
                }

                it("does not crash if effects are dispatched after `dispose`") {
                    dispose()
                    let dispatchEffectsAfterDispose = {
                        dispatchEffect(.innerEffect(.effect1))
                        dispatchEffect(.innerEffect(.effect2))
                    }
                    expect(dispatchEffectsAfterDispose()).toNot(throwError())
                    expect(dispatchEffectsAfterDispose()).toNot(raiseException())
                    expect(dispatchEffectsAfterDispose()).toNot(throwAssertion())
                }
            }

            context("reconnecting after dispose") {
                it("is possible to connect again after the effect handler has been disposed") {
                    dispatchEffect(.innerEffect(.effect1))
                    dispose()
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

private func canAccept(effect: OuterEffect) -> HandleEffect<InnerEffect> {
    switch effect {
    case .innerEffect(let effect):
        if effect == .effect1 {
            return .handle(effect)
        } else {
            return .ignore
        }
    }
}
