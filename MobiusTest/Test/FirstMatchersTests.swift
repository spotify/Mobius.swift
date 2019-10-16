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
import MobiusTest
import Nimble
import Quick

class FirstMatchersTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("assertThatFirst") {
            var failureMessages: [String] = []
            let model = "3"

            func testInitiator(model: String) -> First<String, String> {
                return First<String, String>(model: model, effects: ["2", "4"])
            }

            func failureDetector(message: String, file: StaticString, line: UInt) {
                failureMessages.append(message)
            }

            beforeEach {
                failureMessages = []
            }

            // Testing through proxy: InitSpec
            context("when asserting through predicates that fail") {
                beforeEach {
                    InitSpec<AllStrings>(testInitiator)
                        .when("a model")
                        .then(assertThatFirst(
                            hasModel(model + "1"),
                            hasNoEffects(),
                            failFunction: failureDetector
                        ))
                }

                it("should have registered all failures") {
                    expect(failureMessages.count).to(equal(2))
                }
            }
        }

        describe("FirstMatchers") {
            let expectedModel = 1
            var result: MobiusTest.PredicateResult?

            beforeEach {
                result = nil
            }

            context("when creating a matcher to check a First for a specific model") {
                context("when the model is the expected") {
                    beforeEach {
                        let first = First<Int, Int>(model: expectedModel)
                        let sut: FirstPredicate<Int, Int> = hasModel(expectedModel)
                        result = sut(first)
                    }

                    it("should match") {
                        expect(result?.wasSuccessful).to(beTrue())
                    }
                }

                context("when the model isn't the expected") {
                    let actualModel = 2
                    beforeEach {
                        let first = First<Int, Int>(model: actualModel)
                        let sut: FirstPredicate<Int, Int> = hasModel(expectedModel)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result?.failureMessage).to(equal("Expected model to be <\(expectedModel)>, got <\(actualModel)>"))
                    }
                }
            }

            context("when creating a matcher to check that a First has no effects") {
                context("when the First has no effects") {
                    beforeEach {
                        let first = First<Int, Int>(model: 3)
                        let sut: FirstPredicate<Int, Int> = hasNoEffects()
                        result = sut(first)
                    }

                    it("should match") {
                        expect(result?.wasSuccessful).to(beTrue())
                    }
                }

                context("when the First has effects") {
                    let effects = [4]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: effects)
                        let sut: FirstPredicate<Int, Int> = hasNoEffects()
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result?.failureMessage).to(equal("Expected no effects, got <\(effects)>"))
                    }
                }
            }

            context("when creating a matcher to check that a First has specific effects") {
                context("when the First has those effects") {
                    let expectedEffects = [4, 7, 0]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: expectedEffects)
                        let sut: FirstPredicate<Int, Int> = hasEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should match") {
                        expect(result?.wasSuccessful).to(beTrue())
                    }
                }

                context("when the First contains the expected effects and a few more") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [1, 4, 7, 0]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should match") {
                        expect(result?.wasSuccessful).to(beTrue())
                    }
                }

                context("when the First does not contain all the expected effects") {
                    let expectedEffects = [10]
                    let actualEffects = [4]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result?.failureMessage).to(equal("Expected effects <\(actualEffects)> to contain <\(expectedEffects)>"))
                    }
                }
            }
        }
    }
}
