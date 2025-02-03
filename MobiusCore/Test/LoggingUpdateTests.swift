// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore
import Nimble
import Quick

class LoggingUpdateTests: QuickSpec {
    override func spec() {
        describe("LoggingUpdate") {
            var logger: TestMobiusLogger!
            var loggingUpdate: Update<String, String, String>!

            beforeEach {
                logger = TestMobiusLogger()
                loggingUpdate = logger.wrap(update: Update { model, event in Next(model: model, effects: [event]) })
            }

            it("should log willUpdate and didUpdate for each update attempt") {
                _ = loggingUpdate.update(model: "from this", event: "ee")

                expect(logger.logMessages).to(equal(["willUpdate(from this, ee)", "didUpdate(from this, ee, (\"from this\", [\"ee\"]))"]))
            }

            it("should return update from delegate") {
                let next = loggingUpdate.update(model: "hey", event: "event/effect")

                expect(next.model).to(equal("hey"))
                expect(next.effects).to(equal(["event/effect"]))
            }
        }
    }
}
