// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

class AnyMobiusLoggerTests: QuickSpec {
    override class func spec() {
        describe("AnyMobiusLogger") {
            var delegate: TestMobiusLogger!
            var logger: AnyMobiusLogger<String, String, String>!

            beforeEach {
                delegate = TestMobiusLogger()
                logger = AnyMobiusLogger(delegate)
            }

            it("should forward willInitiate messages to delegate") {
                logger.willInitiate(model: "will initiate")

                expect(delegate.logMessages).to(equal(["willInitiate(will initiate)"]))
            }

            it("should forward didInitiate messages to delegate") {
                logger.didInitiate(model: "did start it", first: First(model: "the first model"))

                expect(delegate.logMessages).to(equal([
                    "didInitiate(did start it, First<String, String>(model: \"the first model\", effects: []))",
                ]))
            }

            it("should forward willUpdate messages to delegate") {
                logger.willUpdate(model: "different model", event: "but it's a better test, or?")

                expect(delegate.logMessages).to(equal([
                    "willUpdate(different model, but it's a better test, or?)",
                ]))
            }

            it("should forward didUpdate messages to delegate") {
                logger.didUpdate(model: "wrong order", event: "but it's a better test", next: Next.next("or?"))

                expect(delegate.logMessages).to(equal([
                    "didUpdate(wrong order, but it's a better test, (\"or?\", []))",
                ]))
            }
        }
    }
}
