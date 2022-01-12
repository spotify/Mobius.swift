// Copyright 2019-2022 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
