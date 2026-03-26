// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import MobiusCore
import MobiusTest
import Nimble
import Quick

class InitSpecTests: QuickSpec {
    override class func spec() {
        describe("InitSpec") {
            context("when setting up a test scenario") {
                var initiate: Initiate<String, String>!
                var spec: InitSpec<String, String>!
                var testModel: String!
                var testEffects: [String]!
                var assertionClosureCalled = false

                beforeEach {
                    testModel = UUID().uuidString
                    testEffects = ["1", "2", "3"]
                    initiate = { (model: String) in
                        First(model: model + model, effects: testEffects)
                    }

                    spec = InitSpec(initiate)
                }

                it("should run the test provided") {
                    spec.when(testModel).then({ (first: First<String, String>) in
                        assertionClosureCalled = true
                        expect(first.model).to(equal(testModel + testModel))
                        expect(first.effects).to(equal(testEffects))
                    })

                    expect(assertionClosureCalled).to(beTrue())
                }
            }
        }
    }
}
