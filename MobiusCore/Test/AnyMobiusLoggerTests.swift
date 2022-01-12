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

import MobiusCore
import Nimble
import Quick

class AnyMobiusLoggerTests: QuickSpec {
    override func spec() {
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
