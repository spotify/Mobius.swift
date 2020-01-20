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

private typealias Event = ()

private enum Effect: Equatable {
    case justEffect
    case effectWithString(String)
    case effectWithTuple(left: String, right: Int)
}

private indirect enum List: Equatable {
    case singleton(String)
}

class PayloadExtractionRouteTests: QuickSpec {
    override func spec() {
        context("Different types of enums being unwrapped") {
            it("supports routing to an effect with nothing to unwrap") {
                var receivedEffect: Effect? = nil
                let handler = EffectRouter<Effect, Effect>()
                    .routeCase(.justEffect)
                        .to { effect in
                            receivedEffect = effect
                        }
                    .asConnectable
                    .connect { _ in }

                handler.accept(.justEffect)
                expect(receivedEffect).to(equal(.justEffect))
                handler.dispose()
            }

            it("supports unwrapping an effect with a string") {
                var unwrapped: String? = nil
                let handler = EffectRouter<Effect, Event>()
                    .routeEnumCase(Effect.effectWithString)
                        .to { payload in unwrapped = payload }
                    .asConnectable
                    .connect { _ in }

                handler.accept(.effectWithString("Test"))
                expect(unwrapped).to(equal("Test"))
                handler.dispose()
            }

            it("supports unwrapping an effect with a tuple") {
                var leftUnwrapped: String? = nil
                var rightUnwrapped: Int? = nil
                let handler = EffectRouter<Effect, Event>()
                    .routeEnumCase(Effect.effectWithTuple)
                    .to { payload in
                        let (left, right) = payload
                        leftUnwrapped = left
                        rightUnwrapped = right
                    }
                    .asConnectable
                    .connect { _ in }

                handler.accept(.effectWithTuple(left: "Test", right: 1))
                expect(leftUnwrapped).to(equal("Test"))
                expect(rightUnwrapped).to(equal(1))
                handler.dispose()
            }

            it("supports unwrapping an indirect type") {
                var result: String? = nil
                let handler = EffectRouter<List, Event>()
                    .routeEnumCase(List.singleton)
                    .to { payload in
                        result = payload
                    }
                    .asConnectable
                    .connect { _ in }

                handler.accept(.singleton("Test"))
                expect(result).to(equal("Test"))
                handler.dispose()
            }
        }
    }
}
