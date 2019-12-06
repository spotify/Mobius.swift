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

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class MobiusHooksTests: QuickSpec {
    override func spec() {
        let someString = UUID().uuidString

        describe("MobiusHooks") {
            context("when setting a custom error handler") {
                var errorMessage: String?
                var errorFile: String?
                var errorLine: UInt?
                var errorCalledOnLine: UInt!

                beforeEach {
                    MobiusHooks.setErrorHandler({ (message: String, file: StaticString, line: UInt) in
                        errorMessage = message
                        errorFile = String(file)
                        errorLine = line
                    })

                    errorCalledOnLine = #line + 1
                    MobiusHooks.onError(someString)
                }

                afterEach {
                    MobiusHooks.setDefaultErrorHandler()
                }

                it("should use that error handler when an error occurs") {
                    expect(errorMessage).to(match(someString))
                }

                it("should report the correct file") {
                    let currentFile = #file
                    expect(errorFile).to(equal(currentFile))
                }

                it("should report the correct line") {
                    expect(errorLine).to(equal(errorCalledOnLine))
                }
            }
        }
    }
}

private extension String {
    init(_ staticString: StaticString) {
        self = staticString.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }
}
