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

class BrokenConnectionTests: QuickSpec {
    override func spec() {
        var connection: Connection<Int>!
        var errorThrown: Bool!

        describe("BrokenAnyConnection") {
            beforeEach {
                connection = BrokenConnection<Int>.connection()
                errorThrown = false
                MobiusHooks.setErrorHandler({ _, _, _ in
                    errorThrown = true
                })
            }

            afterEach {
                MobiusHooks.setDefaultErrorHandler()
            }

            context("when calling accept value") {
                it("should trigger the error handler") {
                    connection.accept(3)
                    expect(errorThrown).to(beTrue())
                }
            }

            context("when attempting to dispose") {
                it("should trigger the error handler") {
                    connection.dispose()
                    expect(errorThrown).to(beTrue())
                }
            }
        }
    }
}
