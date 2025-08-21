// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusExtras
import Nimble
import Quick

class CopyableTests: QuickSpec {
    private struct Model: Equatable, Copyable {
        var name: String
        var age: Int
    }

    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("Copyable") {
            var model: Model!

            beforeEach {
                model = Model(name: "Aron", age: 29)
            }

            describe("default copy(with:) implementation") {
                it("should call the mutator") {
                    var didCall = false
                    _ = model.copy { _ in didCall = true }

                    expect(didCall).to(beTrue())
                }

                it("should return a copy") {
                    expect(model.copy { $0.age = 30 }).to(equal(Model(name: "Aron", age: 30)))
                }
            }
        }
    }
}
