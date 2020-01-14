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

class ResponseTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("Responses") {
            context("Ending a response") {
                var onEndCalledTimes: Int!
                var response: EffectCallback<Int>!

                beforeEach {
                    onEndCalledTimes = 0
                    response = EffectCallback(onSend: { _ in }, onEnd: {
                        onEndCalledTimes += 1
                    })
                }
                it("calls the supplied `onEnd` when `.end()` is called") {
                    response.end()

                    expect(onEndCalledTimes).to(equal(1))
                }

                it("only calls `onEnd` once when `end` is called") {
                    response.end()
                    response.end()
                    response.end()

                    expect(onEndCalledTimes).to(equal(1))
                }

                it("calls `onEnd` when the Response is deinitialized") {
                    var onEndCalled = false
                    var response: EffectCallback<Int>? = EffectCallback(onSend: { _ in }, onEnd: {
                        onEndCalled = true
                    })

                    response = nil

                    expect(response).to(beNil())
                    expect(onEndCalled).toEventually(beTrue())
                }
            }

            context("Sending output") {
                var output: [Int]!
                var response: EffectCallback<Int>!

                beforeEach {
                    output = []
                    response = EffectCallback(onSend: { output.append($0) }, onEnd: {})
                }

                it("calls `onSend` when `.send` is called with the same argument") {
                    response.send(1)
                    expect(output).to(equal([1]))
                }

                it("stops calling `onSend` after `.end` has been called") {
                    response.send(1)
                    response.send(2)
                    expect(output).to(equal([1, 2]))

                    response.end()

                    response.send(3)
                    expect(output).to(equal([1, 2]))
                }
            }
        }
    }
}
