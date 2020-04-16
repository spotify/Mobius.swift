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

class ConnectionTests: QuickSpec {
    override func spec() {
        describe("Connection") {
            context("when initialising with closures") {
                var connection: Connection<Int>!
                var acceptValue: Int?
                var disposeCalled = false

                beforeEach {
                    let acceptClosure = { (value: Int) in acceptValue = value }
                    let disposeClosure = { disposeCalled = true }
                    connection = Connection(acceptClosure: acceptClosure, disposeClosure: disposeClosure)
                }

                afterEach {
                    acceptValue = nil
                    disposeCalled = false
                }

                it("should set up the dispose closure correctly") {
                    connection.dispose()
                    expect(disposeCalled).to(beTrue())
                }

                it("should set up the accept closure correctly") {
                    let testValue = 4
                    connection.accept(testValue)
                    expect(acceptValue).to(equal(testValue))
                }
            }
        }
    }
}
