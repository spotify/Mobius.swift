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
@testable import MobiusNimble
import MobiusTest
import Nimble
import Quick
import XCTest

// The assertions in these tests are using XCTest assertions since the assertion handler for Nimble
// is replaced in order to be inspected

// swiftlint:disable file_length
// swiftlint:disable type_body_length
class NimbleNextMatchersTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        let assertionHandler = AssertionRecorder()
        var defaultHandler: AssertionHandler?

        describe("assertThatNext") {
            beforeEach {
                // A solution with `withAssertionHandler` (see Nimble documentation) doesn't work (the assertion handler
                // is not being used inside the block).
                // Doing a hack around it
                defaultHandler = NimbleAssertionHandler
                NimbleAssertionHandler = assertionHandler
            }

            afterEach {
                NimbleAssertionHandler = defaultHandler!
            }

            let testUpdate = Update<String, String, String> { model, _ in
                model = "some model"
                return ["some effect"]
            }

            // Testing through proxy: UpdateSpec
            context("when asserting through predicates that fail") {
                beforeEach {
                    UpdateSpec<String, String, String>(testUpdate)
                        .given("a model")
                        .when("")
                        .then(assertThatNext(haveNoModel(), haveNoEffects()))
                }

                it("should have registered all failures") {
                    XCTAssertEqual(assertionHandler.assertions.count, 2)
                }
            }
        }

        describe("NimbleNextMatchers") {
            beforeEach {
                // A solution with `withAssertionHandler` (see Nimble documentation) doesn't work (the assertion handler
                // is not being used inside the block).
                // Doing a hack around it
                defaultHandler = NimbleAssertionHandler
                NimbleAssertionHandler = assertionHandler
            }

            afterEach {
                NimbleAssertionHandler = defaultHandler!
            }

            context("when creating a matcher verifying that a Next has no model and no effects") {
                let effects = [4]
                let model = 1

                context("when matching a Next that has no model and no effects") {
                    beforeEach {
                        let next = Next<Int, Int>.noChange
                        expect(next).to(haveNothing())
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when matching a Next that has a model but no effects") {
                    beforeEach {
                        let next = Next<Int, Int>.next(model)
                        expect(next).to(haveNothing())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }
                }

                context("when matching a Next that has effects but no model") {
                    beforeEach {
                        let next = Next<Int, Int>.dispatchEffects(effects)
                        expect(next).to(haveNothing())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }
                }

                context("when matching a Next that has model and effects") {
                    beforeEach {
                        let next = Next<Int, Int>.next(model, effects: effects)
                        expect(next).to(haveNothing())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let next: Next<String, String>? = nil
                        expect(next).to(haveNothing())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(haveNonNilNext)
                    }
                }
            }

            context("when creating a matcher to verify that a Next has a specific model") {
                let expectedModel = "This is a model"

                context("when matching a Next that has the specific model") {
                    beforeEach {
                        let next = Next<String, String>.next(expectedModel)
                        expect(next).to(haveModel(expectedModel))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when matching a Next that does not have the specific model") {
                    let model = "some strange model"

                    beforeEach {
                        let next = Next<String, String>.next(model)
                        expect(next).to(haveModel(expectedModel))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageHasSuffix("be <\(expectedModel)>, got <\(model)>")
                    }
                }

                context("when matching a Next that has no model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["cherry"])
                        expect(next).to(haveModel("apple"))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageHasSuffix("have a model")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let next: Next<String, String>? = nil
                        expect(next).to(haveModel("grapefruit"))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(haveNonNilNext)
                    }
                }
            }

            context("when creating a matcher to verify that a Next has any model") {
                context("when matching a Next with a model") {
                    let model = "lichi"
                    beforeEach {
                        let next = Next<String, String>.next(model)
                        expect(next).to(haveModel())
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when matching a Next without a model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["1", "3"])
                        expect(next).to(haveModel())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageHasSuffix("not have a <nil> model")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let next: Next<String, String>? = nil
                        expect(next).to(haveModel())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(haveNonNilNext)
                    }
                }
            }

            context("when creating a matcher verifying that a Next has no model") {
                context("when matching a Next that has no model") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["1", "2"])
                        expect(next).to(haveNoModel())
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when matching a Next that has a different model") {
                    let model = "pomegranate"
                    beforeEach {
                        let next = Next<String, String>.next(model)
                        expect(next).to(haveNoModel())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageHasSuffix("have no model, got <\(model)>")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let next: Next<String, String>? = nil
                        expect(next).to(haveNoModel())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(haveNonNilNext)
                    }
                }
            }

            context("when creating a matcher verifying that a Next has no effects") {
                context("when matching a Next that has no effects") {
                    beforeEach {
                        let next = Next<String, String>.next("durian")
                        expect(next).to(haveNoEffects())
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when matching a Next that has effects") {
                    beforeEach {
                        let next = Next<String, String>.dispatchEffects(["durian"])
                        expect(next).to(haveNoEffects())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("have no effects")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let next: Next<String, String>? = nil
                        expect(next).to(haveNoEffects())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(haveNonNilNext)
                    }
                }
            }

            context("when creating a matcher verifying that a Next has specific effects") {
                var expected: [Int]!
                beforeEach {
                    expected = [4]
                }
                context("when the effects are the same") {
                    beforeEach {
                        let next = Next<String, Int>.dispatchEffects(expected)
                        expect(next).to(haveEffects(expected))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the Next contains the expected effects and a few more") {
                    let actual = [1, 2, 3, 4, 5, 0]
                    beforeEach {
                        let next = Next<String, Int>.dispatchEffects(actual)
                        expect(next).to(haveEffects(expected))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the Next does not contain one or more of the expected effects") {
                    var actual: [Int]!
                    beforeEach {
                        actual = [1]
                        let next = Next<String, Int>.dispatchEffects(actual)
                        expect(next).to(haveEffects(expected))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("contain <\(expected!)>, got <\(actual!)>")
                    }
                }

                context("when there are no effects") {
                    context("when not expecting effects") {
                        beforeEach {
                            let next = Next<String, Int>.noChange
                            expect(next).to(haveEffects([]))
                        }

                        it("should match") {
                            assertionHandler.assertExpectationSucceeded()
                        }
                    }

                    context("when expecting effects") {
                        beforeEach {
                            let next = Next<String, Int>.noChange
                            expect(next).to(haveEffects(expected))
                        }

                        it("should no match") {
                            assertionHandler.assertExpectationFailed()
                        }

                        it("should produce an appropriate error message") {
                            assertionHandler.assertLastErrorMessageContains("contain <\(expected!)>, got <[]>")
                        }
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let next: Next<String, Int>? = nil
                        expect(next).to(haveEffects(expected))
                    }

                    it("should no match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(haveNonNilNext)
                    }
                }
            }
        }
    }
}
