// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

class ConnectionTests: QuickSpec {
    override class func spec() {
        describe("Connection") {
            context("when initializing with closures") {
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
