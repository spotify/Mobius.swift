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
@testable import MobiusTest
import Nimble
import Quick
import XCTest

// The assertions in these tests are using XCTest assertions since the assertion handler for Nimble
// is replaced in order to be inspected

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class XCTestNextMatchersTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("AssertThatNext") {
            var failMessages: [String] = []

            func assertionFailed(message: String, file: StaticString, line: UInt) {
                failMessages.append(message)
            }

            beforeEach {
                failMessages = []
            }

            let testUpdate = Update<String, String, String>.create { _, _ in
                .next("some model", effects: ["some effect"])
            }

            // Testing through proxy: UpdateSpec
            context("when asserting through predicates that fail") {
                beforeEach {
                    UpdateSpec<String, String, String>(testUpdate)
                        .given("a model")
                        .when("")
                        .then(assertThatNext(
                            hasNoModel(),
                            hasNoEffects(),
                            failFunction: assertionFailed
                        ))
                }

                it("should have registered all failures") {
                    XCTAssertEqual(failMessages.count, 2)
                }
            }
        }

        describe("XCTestNextMatchers") {
            var result: MobiusTest.PredicateResult!

            context("when creating a matcher verifying that a Next has no model and no effects") {
                let effects = ["tomato"]
                let model = "dragonfruit"
                var sut: NextPredicate<String, String>!

                beforeEach {
                    sut = hasNothing()
                }

                context("when matching a Next that has no model and no effects") {
                    beforeEach {
                        let next = Next<String, String>.noChange
                        result = sut(next)
                    }

                    it("should match") {
                        expect(result.wasSuccessful).to(beTrue())
                    }
                }

                context("when matching a Next that has a model but no effects") {
                    beforeEach {
                        let next = Next<String, String>.next(model)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected final Next to have no model. Got: <\(model)>"))
                    }
                }

                context("when matching a Next that has effects but no model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(effects)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected no effects. Got: <\(effects)>"))
                    }
                }

                context("when matching a Next that has model and effects") {
                    beforeEach {
                        let next = Next<String, String>.next(model, effects: effects)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected final Next to have no model. Got: <\(model)>"))
                    }
                }
            }

            context("when creating a matcher to verify that a Next has a specific model") {
                let expectedModel = "banana"
                var sut: NextPredicate<String, String>!

                beforeEach {
                    sut = hasModel(expectedModel)
                }

                context("when matching a Next that has the specific model") {
                    beforeEach {
                        let next = Next<String, String>.next(expectedModel)
                        result = sut(next)
                    }

                    it("should match") {
                        expect(result.wasSuccessful).to(beTrue())
                    }
                }

                context("when matching a Next that does not have the specific model") {
                    let actualModel = "apple"

                    beforeEach {
                        let next = Next<String, String>.next(actualModel)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        let optionalActual: String? = actualModel
                        let expectedError = "Expected final Next to have model: <\(expectedModel)>. Got: <\(String(describing: optionalActual))>"
                        expect(result.failureMessage).to(equal(expectedError))
                    }
                }

                context("when matching a Next that has no model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["cherry"])
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected final Next to have model: <\(expectedModel)>. Got: <nil>"))
                    }
                }
            }

            context("when creating a matcher to verify that a Next has any model") {
                var sut: NextPredicate<String, String>!

                beforeEach {
                    sut = hasModel()
                }

                context("when matching a Next with a model") {
                    let model = "lichi"
                    beforeEach {
                        let next = Next<String, String>.next(model)
                        result = sut(next)
                    }

                    it("should match") {
                        expect(result.wasSuccessful).to(beTrue())
                    }
                }

                context("when matching a Next without a model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["1", "3"])
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected final Next to have a model. Got: <nil>"))
                    }
                }
            }

            context("when creating a matcher verifying that a Next has no model") {
                var sut: NextPredicate<String, String>!

                beforeEach {
                    sut = hasNoModel()
                }

                context("when matching a Next that has no model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["1", "2"])
                        result = sut(next)
                    }

                    it("should match") {
                        expect(result.wasSuccessful).to(beTrue())
                    }
                }

                context("when matching a Next that has a different model") {
                    let model = "pomegranate"
                    beforeEach {
                        let next = Next<String, String>.next(model)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected final Next to have no model. Got: <\(model)>"))
                    }
                }
            }

            context("when creating a matcher verifying that a Next has no effects") {
                var sut: NextPredicate<String, String>!

                beforeEach {
                    sut = hasNoEffects()
                }

                context("when matching a Next that has no effects") {
                    beforeEach {
                        let next = Next<String, String>.next("durian")
                        result = sut(next)
                    }

                    it("should match") {
                        expect(result.wasSuccessful).to(beTrue())
                    }
                }

                context("when matching a Next that has effects") {
                    let actual = ["grapefruit"]
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(actual)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected no effects. Got: <\(actual)>"))
                    }
                }
            }

            context("when creating a matcher verifying that a Next has specific effects") {
                let expected = [1, 2, 3, 4]
                var sut: NextPredicate<String, Int>!

                beforeEach {
                    sut = hasEffects(expected)
                }

                context("when the effects are the same") {
                    context("when the effects are in order") {
                        beforeEach {
                            let next = Next<String, Int>.dispatchEffects(expected)
                            result = sut(next)
                        }

                        it("should match") {
                            expect(result.wasSuccessful).to(beTrue())
                        }
                    }

                    context("when the effects are out of order") {
                        beforeEach {
                            var actual = expected
                            actual.append(actual.removeFirst())
                            let next = Next<String, Int>.dispatchEffects(actual)
                            result = sut(next)
                        }

                        it("should match") {
                            expect(result.wasSuccessful).to(beTrue())
                        }
                    }
                }

                context("when the Next contains the expected effects and a few more") {
                    let actual = [1, 2, 3, 4, 5, 0]
                    beforeEach {
                        let next = Next<String, Int>.dispatchEffects(actual)
                        result = sut(next)
                    }

                    it("should match") {
                        expect(result.wasSuccessful).to(beTrue())
                    }
                }

                context("when the Next does not contain one or more of the expected effects") {
                    let actual = [1]
                    let expected = [3]
                    beforeEach {
                        let next = Next<String, Int>.dispatchEffects(actual)
                        sut = hasEffects(expected)
                        result = sut(next)
                    }

                    it("should fail with an appropriate error message") {
                        expect(result.failureMessage).to(equal("Expected <\(actual)> to contain <\(expected)>"))
                    }
                }

                context("when there are no effects") {
                    context("when not expecting effects") {
                        beforeEach {
                            let next = Next<String, String>.noChange
                            let sut: NextPredicate<String, String> = hasEffects([])
                            result = sut(next)
                        }

                        it("should match") {
                            expect(result.wasSuccessful).to(beTrue())
                        }
                    }

                    context("when expecting effects") {
                        let expected = [88]
                        beforeEach {
                            let next = Next<String, Int>.noChange
                            sut = hasEffects(expected)
                            result = sut(next)
                        }

                        it("should fail with an appropriate error message") {
                            expect(result.failureMessage).to(equal("Expected <[]> to contain <\(expected)>"))
                        }
                    }
                }
            }
        }
    }
}
