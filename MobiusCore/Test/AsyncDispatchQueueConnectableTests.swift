// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore

import Foundation
import Nimble
import Quick

class AsyncDispatchQueueConnectableTests: QuickSpec {
    override class func spec() {
        describe("AsyncDispatchQueueConnectable") {
            var connectable: AsyncDispatchQueueConnectable<String, String>!
            var underlyingConnectable: RecordingTestConnectable!
            let acceptQueue = DispatchQueue(label: "accept queue")

            beforeEach {
                underlyingConnectable = RecordingTestConnectable(expectedQueue: acceptQueue)
                connectable = AsyncDispatchQueueConnectable(underlyingConnectable, acceptQueue: acceptQueue)
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
