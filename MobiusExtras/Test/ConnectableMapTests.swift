// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import MobiusExtras
import Nimble
import Quick

class ConnectableMapTests: QuickSpec {
    override func spec() {
        context("Connectable Map") {
            it("applies the `transform` function to the output") {
                var output: [Int?] = []
                let connection = TestConnectable()
                    .map { Int($0) }
                    .connect {
                        output.append($0)
                    }

                connection.accept("1")
                connection.accept("2")
                connection.accept("3")

                expect(output).to(equal([1, 2, 3]))

                connection.dispose()
            }

            it("preserves the connectable's `Disposable` conformance") {
                let testConnectable = TestConnectable()
                expect(testConnectable.isDisposed).to(beFalse())

                testConnectable
                    .connect { _ in }
                    .dispose()

                expect(testConnectable.isDisposed).to(beTrue())
            }
        }
    }
}

private final class TestConnectable: Connectable {
    var isDisposed = false

    func connect(_ consumer: @escaping Consumer<String>) -> Connection<String> {
        return Connection(
            acceptClosure: consumer,
            disposeClosure: { self.isDisposed = true }
        )
    }
}
