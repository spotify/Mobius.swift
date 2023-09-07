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
import MobiusExtras
import Nimble
import Quick

final class ConnectableCompactMapTests: QuickSpec {
    override func spec() {
        context("Connectable Compact Map") {
            it("applies the `transform` function to the output") {
                var output: [Int] = []
                let connection = TestConnectable()
                    .compactMap { Int($0) }
                    .connect {
                        output.append($0)
                    }

                connection.accept("1")
                connection.accept("A")
                connection.accept("2")
                connection.accept("B")
                connection.accept("3")
                connection.accept("C")

                expect(output).to(equal([1, 2, 3]))

                connection.dispose()
            }

            it("preserves the connectable's `Disposable` conformance") {
                let testConnectable = TestConnectable()
                expect(testConnectable.isDisposed).to(beFalse())

                testConnectable
                    .compactMap { Int($0) }
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
