// Copyright (c) 2020 Spotify AB.
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
@testable import MobiusTest
import Nimble
import Quick

class FirstMatchersTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("assertThatFirst") {
            var failureMessages: [String] = []
            let model = "3"

            func testInitiate(model: String) -> First<String, String> {
                return First(model: model, effects: ["2", "4"])
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
                    InitSpec(testInitiate)
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
                        expect(result?.failureMessage).to(equal("Different model than expected (−), got (+): \n\(dumpDiff(expectedModel, actualModel))"))
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
                        let expectedError = "Missing 1 expected effect (−), got (+) (with 1 actual effect unmatched):\n"
                            + dumpDiffFuzzy(expected: expectedEffects, actual: actualEffects, withUnmatchedActual: false)
                        expect(result?.failureMessage).to(equal(expectedError))
                    }
                }
            }

            context("when creating a matcher to check that a First has only specific effects") {
                context("when the First has those effects") {
                    let expectedEffects = [4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: expectedEffects)
                        let sut: FirstPredicate<Int, Int> = hasOnlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should match") {
                        expect(result?.wasSuccessful).to(beTrue())
                    }
                }

                context("when the First has those effects in different order") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [0, 7, 4]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasOnlyEffects(expectedEffects)
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
                        let sut: FirstPredicate<Int, Int> = hasOnlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        let expectedError = "Got 1 actual unmatched effect (+):\n" +
                            dumpDiffFuzzy(expected: [], actual: [1], withUnmatchedActual: true)
                        expect(result?.failureMessage).to(equal(expectedError))
                    }
                }

                context("when the First does not contain all the expected effects") {
                    let expectedEffects = [10]
                    let actualEffects = [4]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasOnlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        let expectedError = "Missing 1 expected effect (−), got 1 actual unmatched effect (+):\n" +
                            dumpDiffFuzzy(expected: expectedEffects, actual: actualEffects, withUnmatchedActual: true)
                        expect(result?.failureMessage).to(equal(expectedError))
                    }
                }
            }

            context("when creating a matcher to check that a First has exact effects") {
                context("when the First has those effects") {
                    let expectedEffects = [4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: expectedEffects)
                        let sut: FirstPredicate<Int, Int> = hasExactlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should match") {
                        expect(result?.wasSuccessful).to(beTrue())
                    }
                }

                context("when the First has those effects in different order") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [0, 7, 4]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasExactlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        let expectedError = "Different effects than expected (−), got (+): \n\(dumpDiff(expectedEffects, actualEffects))"
                        expect(result?.failureMessage).to(equal(expectedError))
                    }
                }

                context("when the First contains the expected effects and a few more") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [1, 4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasExactlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        let expectedError = "Different effects than expected (−), got (+): \n\(dumpDiff(expectedEffects, actualEffects))"
                        expect(result?.failureMessage).to(equal(expectedError))
                    }
                }

                context("when the First does not contain all the expected effects") {
                    let expectedEffects = [10]
                    let actualEffects = [4]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        let sut: FirstPredicate<Int, Int> = hasExactlyEffects(expectedEffects)
                        result = sut(first)
                    }

                    it("should fail with an appropriate error message") {
                        let expectedError = "Different effects than expected (−), got (+): \n\(dumpDiff(expectedEffects, actualEffects))"
                        expect(result?.failureMessage).to(equal(expectedError))
                    }
                }
            }
        }
    }
}
