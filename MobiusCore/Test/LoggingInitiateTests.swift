// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore
import Nimble
import Quick

class LoggingInitiateTests: QuickSpec {
    override func spec() {
        describe("LoggingInitiate") {
            var logger: TestMobiusLogger!
            var loggingInitiate: Initiate<String, String>!

            beforeEach {
                logger = TestMobiusLogger()
                loggingInitiate = logger.wrap { model in First(model: model) }
            }

            it("should log willInitiate and didInitiate for each initiate attempt") {
                _ = loggingInitiate("from this")

                expect(logger.logMessages).to(equal(["willInitiate(from this)", "didInitiate(from this, First<String, String>(model: \"from this\", effects: []))"]))
            }

            it("should return init from delegate") {
                let first = loggingInitiate("hey")

                expect(first.model).to(equal("hey"))
                expect(first.effects).to(beEmpty())
            }
        }
    }
}
