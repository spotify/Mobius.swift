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
import Nimble
import Quick

class BlockingFunctionConnectableTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("BlockingFunctionConnectable") {
            var functionCalledWithValue: String?
            var functionCalled: Bool!
            var output: String?
            var inputHandler: Connection<String>!

            let expectedOutput = "pong"

            beforeEach {
                functionCalledWithValue = nil
                functionCalled = false
                let sut = BlockingFunctionConnectable<String, String>({ string in
                    functionCalledWithValue = string
                    functionCalled = true
                    return expectedOutput
                })

                output = nil
                inputHandler = sut.connect({ string in
                    output = string
                })
            }

            context("when calling connect") {
                let input = "ping"
                beforeEach {
                    inputHandler.accept(input)
                }
                it("should create a connection with the accept function running the supplied action") {
                    expect(functionCalledWithValue).to(equal(input))
                }

                it("should call the consumer") {
                    expect(output).to(equal(expectedOutput))
                }
            }

            context("after disposed") {
                beforeEach {
                    inputHandler.dispose()
                }
                context("when calling connect") {
                    beforeEach {
                        inputHandler.accept("hej")
                    }
                    it("should not run the supplied action") {
                        expect(functionCalled).to(beFalse())
                    }
                }
            }
        }
    }
}
