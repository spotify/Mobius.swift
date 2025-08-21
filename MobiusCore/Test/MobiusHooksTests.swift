// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class MobiusHooksTests: QuickSpec {
    override class func spec() {
        let someString = UUID().uuidString

        describe("MobiusHooks") {
            context("when setting a custom error handler") {
                var errorMessage: String?
                var errorFile: String?
                var errorLine: UInt?
                var errorCalledOnLine: UInt!

                beforeEach {
                    errorCalledOnLine = #line + 1
                    expect(MobiusHooks.errorHandler(someString, #file, #line)).to(raiseError { message, file, line in
                        errorMessage = message
                        errorFile = file
                        errorLine = line
                    })
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
