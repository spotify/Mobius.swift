// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
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
                    sut = First(model: "a", effects: [.send])
                }

                it("should set the model property") {
                    expect(sut.model).to(equal("a"))
                }

                it("should set the effects property") {
                    expect(sut.effects).to(contain(Effect.send))
                    expect(sut.effects).toNot(contain(Effect.refresh))
                }
            }
        }
    }
}
