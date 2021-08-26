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
@testable import MobiusNimble
import MobiusTest
import Nimble
import Quick
import XCTest

class NimbleFirstMatchersTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        let assertionHandler = AssertionRecorder()
        var defaultHandler: AssertionHandler?

        describe("assertThatFirst") {
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

            let model = "3"
            func testInitiate(model: String) -> First<String, String> {
                return First(model: model, effects: ["2", "4"])
            }

            // Testing through proxy: UpdateSpec
            context("when asserting through predicates that fail") {
                beforeEach {
                    InitSpec(testInitiate)
                        .when("a model")
                        .then(assertThatFirst(haveModel(model + "1"), haveNoEffects()))
                }

                it("should have registered all failures") {
                    XCTAssertEqual(assertionHandler.assertions.count, 2)
                }
            }
        }

        describe("NimbleFirstMatchers") {
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

            context("when creating a matcher to check a First for a specific model") {
                let expectedModel = 1
                context("when the model is the expected") {
                    beforeEach {
                        let first = First<Int, Int>(model: expectedModel)
                        expect(first).to(haveModel(expectedModel))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the model isn't the expected") {
                    let actualModel = 2
                    beforeEach {
                        let first = First<Int, Int>(model: actualModel)
                        expect(first).to(haveModel(expectedModel))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageHasSuffix("be <\(expectedModel)>, got <\(actualModel)>")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let first: First<Int, Int>? = nil
                        expect(first).to(haveModel(expectedModel))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(nextBeingNilNotAllowed)
                    }
                }
            }

            context("when creating a matcher to check that a First has no effects") {
                context("when the First has no effects") {
                    beforeEach {
                        let first = First<Int, Int>(model: 3)
                        expect(first).to(haveNoEffects())
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the First has effects") {
                    let effects = [4]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: effects)
                        expect(first).to(haveNoEffects())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("have no effect, got <\(effects)>")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let first: First<Int, Int>? = nil
                        expect(first).to(haveNoEffects())
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(nextBeingNilNotAllowed)
                    }
                }
            }

            context("when creating a matcher to check that a First has specific effects") {
                context("when the First has those effects") {
                    let expectedEffects = [4, 7, 0]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: expectedEffects)
                        expect(first).to(haveEffects(expectedEffects))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the First contains the expected effects and a few more") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [1, 4, 7, 0]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveEffects(expectedEffects))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the First does not contain all the expected effects") {
                    let expectedEffects = [4]
                    let actualEffects = [1]
                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveEffects(expectedEffects))
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("contain <\(expectedEffects)>, got <\(actualEffects)> (order doesn't matter)")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let first: First<Int, Int>? = nil
                        expect(first).to(haveEffects([1]))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(nextBeingNilNotAllowed)
                    }
                }
            }

            context("when creating a matcher to check that a First has only specific effects") {
                context("when the First has those effects") {
                    let expectedEffects = [4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: expectedEffects)
                        expect(first).to(haveOnlyEffects(expectedEffects))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the First has those effects out of order") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [0, 7, 4]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveOnlyEffects(expectedEffects))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the First contains the expected effects and a few more") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [1, 4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveOnlyEffects(expectedEffects))
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("contain only <\(expectedEffects)>, got <\(actualEffects)> (order doesn't matter)")
                    }
                }

                context("when the First does not contain all the expected effects") {
                    let expectedEffects = [4, 1]
                    let actualEffects = [1]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveOnlyEffects(expectedEffects))
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("contain only <\(expectedEffects)>, got <\(actualEffects)> (order doesn't matter)")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let first: First<Int, Int>? = nil
                        expect(first).to(haveOnlyEffects([1]))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(nextBeingNilNotAllowed)
                    }
                }
            }

            context("when creating a matcher to check that a First has exact effects") {
                context("when the First has those effects") {
                    let expectedEffects = [4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: expectedEffects)
                        expect(first).to(haveExactlyEffects(expectedEffects))
                    }

                    it("should match") {
                        assertionHandler.assertExpectationSucceeded()
                    }
                }

                context("when the First has those effects out of order") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [0, 7, 4]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveExactlyEffects(expectedEffects))
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("equal <\(expectedEffects)>, got <\(actualEffects)>")
                    }
                }

                context("when the First contains the expected effects and a few more") {
                    let expectedEffects = [4, 7, 0]
                    let actualEffects = [1, 4, 7, 0]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveExactlyEffects(expectedEffects))
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("equal <\(expectedEffects)>, got <\(actualEffects)>")
                    }
                }

                context("when the First does not contain all the expected effects") {
                    let expectedEffects = [4, 1]
                    let actualEffects = [1]

                    beforeEach {
                        let first = First<Int, Int>(model: 3, effects: actualEffects)
                        expect(first).to(haveExactlyEffects(expectedEffects))
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains("equal <\(expectedEffects)>, got <\(actualEffects)>")
                    }
                }

                context("when matching nil") {
                    beforeEach {
                        let first: First<Int, Int>? = nil
                        expect(first).to(haveExactlyEffects([1]))
                    }

                    it("should not match") {
                        assertionHandler.assertExpectationFailed()
                    }

                    it("should produce an appropriate error message") {
                        assertionHandler.assertLastErrorMessageContains(nextBeingNilNotAllowed)
                    }
                }
            }
        }
    }
}
