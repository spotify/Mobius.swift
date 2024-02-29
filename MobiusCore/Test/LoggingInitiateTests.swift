// Copyright 2019-2024 Spotify AB.
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
