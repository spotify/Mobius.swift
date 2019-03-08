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

@testable import MobiusCore
import Nimble
import Quick

class FirstTests: QuickSpec {
    private enum Effect {
        case send
        case refresh
    }

    override func spec() {
        describe("First") {
            var sut: First<String, Effect>!

            describe("public initializer") {
                beforeEach {
                    sut = First<String, Effect>(model: "a", effects: [.send])
                }

                it("should set the model property") {
                    expect(sut.model).to(equal("a"))
                }

                it("should set the effects property") {
                    expect(sut.effects).to(contain(Effect.send))
                    expect(sut.effects).toNot(contain(Effect.refresh))
                }
            }

            describe("hasEffects") {
                context("when the object has multiple effects") {
                    beforeEach {
                        sut = First<String, Effect>(model: "1", effects: [.send, .refresh])
                    }

                    it("should return true") {
                        expect(sut.hasEffects).to(beTrue())
                    }
                }

                context("when the object has one effect") {
                    beforeEach {
                        sut = First<String, Effect>(model: "1", effects: [.refresh])
                    }

                    it("should return true") {
                        expect(sut.hasEffects).to(beTrue())
                    }
                }

                context("when the object does not have any effects") {
                    beforeEach {
                        sut = First<String, Effect>(model: "1", effects: [])
                    }

                    it("should return true") {
                        expect(sut.hasEffects).to(beFalse())
                    }
                }
            }
        }
    }
}
