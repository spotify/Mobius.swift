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

class ConsumerConnectableTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("ConsumerConnectable") {
            var consumerCalledWithValue: String?
            var outputProduced: Bool!
            var inputHandler: Connection<String>!

            beforeEach {
                consumerCalledWithValue = nil
                let sut = ConsumerConnectable<String, String>({ string in
                    consumerCalledWithValue = string
                })

                outputProduced = false
                inputHandler = sut.connect({ _ in
                    outputProduced = true
                })
            }

            context("when calling connect") {
                let input = "hej"
                beforeEach {
                    inputHandler.accept(input)
                }
                it("should create a connection with the accept function running the supplied action") {
                    expect(consumerCalledWithValue).to(equal(input))
                }

                it("should not call the consumer") {
                    expect(outputProduced).to(beFalse())
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
                        expect(consumerCalledWithValue).to(beNil())
                    }
                }
            }
        }
    }
}
