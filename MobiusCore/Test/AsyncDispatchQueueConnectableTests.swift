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

import Foundation
import Nimble
import Quick

class AsyncDispatchQueueConnectableTests: QuickSpec {
    private let acceptQueue = DispatchQueue(label: "accept queue")

    override func spec() {
        describe("AsyncDispatchQueueConnectable") {
            var connectable: AsyncDispatchQueueConnectable<String, String>!
            var underlyingConnectable: RecordingTestConnectable!

            beforeEach {
                underlyingConnectable = RecordingTestConnectable(expectedQueue: self.acceptQueue)
                connectable = AsyncDispatchQueueConnectable(underlyingConnectable, acceptQueue: self.acceptQueue)
            }

            context("when connected") {
                var connection: Connection<String>!
                var dispatchedValue: String?

                beforeEach {
                    connection = connectable.connect { dispatchedValue = $0 }
                }

                afterEach {
                    dispatchedValue = nil
                }

                it("should forward inputs to the underlying connectable") {
                    connection.accept("S")
                    expect(underlyingConnectable.recorder.items).toEventually(equal(["S"]))
                }

                it("should forward outputs from the underlying connectable") {
                    underlyingConnectable.dispatch("S")
                    expect(dispatchedValue).to(equal("S"))
                }

                it("should not allow disposing twice") {
                    expect(connection.dispose()).toNot(raiseError())
                    expect(connection.dispose()).to(raiseError())
                }
            }
        }
    }
}
