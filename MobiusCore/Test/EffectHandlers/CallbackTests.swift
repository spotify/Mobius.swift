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

class CallbackTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("Callbacks") {
            context("Ending a Callback") {
                var onEndCalledTimes: Int!
                var callback: EffectCallback<Int>!

                beforeEach {
                    onEndCalledTimes = 0
                    callback = EffectCallback(onSend: { _ in }, onEnd: {
                        onEndCalledTimes += 1
                    })
                }
                it("calls the supplied `onEnd` when `.end()` is called") {
                    callback.end()

                    expect(onEndCalledTimes).to(equal(1))
                }

                it("only calls `onEnd` once when `end` is called") {
                    callback.end()
                    callback.end()
                    callback.end()

                    expect(onEndCalledTimes).to(equal(1))
                }

                it("calls `onEnd` when the Callback is deinitialized") {
                    var onEndCalled = false
                    var callback: EffectCallback<Int>? = EffectCallback(onSend: { _ in }, onEnd: {
                        onEndCalled = true
                    })

                    callback = nil

                    expect(callback).to(beNil())
                    expect(onEndCalled).toEventually(beTrue())
                }
            }

            context("Sending output") {
                var output: [Int]!
                var callback: EffectCallback<Int>!

                beforeEach {
                    output = []
                    callback = EffectCallback(onSend: { output.append($0) }, onEnd: {})
                }

                it("calls `onSend` when `.send` is called with the same argument") {
                    callback.send(1)
                    expect(output).to(equal([1]))
                }

                it("stops calling `onSend` after `.end` has been called") {
                    callback.send(1)
                    callback.send(2)
                    expect(output).to(equal([1, 2]))

                    callback.end()

                    callback.send(3)
                    expect(output).to(equal([1, 2]))
                }

                it("sends events before ending when using `.end(with:)` with varargs") {
                    callback.end(with: 1, 2, 3)
                    expect(output).to(equal([1, 2, 3]))
                    expect(callback.ended).to(beTrue())
                }

                it("sends events before ending when using `.end(with:)` with an array") {
                    callback.end(with: [1, 2, 3])
                    expect(output).to(equal([1, 2, 3]))
                    expect(callback.ended).to(beTrue())
                }
            }
        }
    }
}
