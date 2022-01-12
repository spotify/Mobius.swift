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
