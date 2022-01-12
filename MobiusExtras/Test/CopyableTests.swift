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

import MobiusExtras
import Nimble
import Quick

class CopyableTests: QuickSpec {
    private struct Model: Equatable, Copyable {
        var name: String
        var age: Int
    }

    // swiftlint:disable:next function_body_length
    override func spec() {
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
