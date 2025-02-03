// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import MobiusExtras
import Nimble
import Quick

class ConnectableContramapTests: QuickSpec {
    override func spec() {
        describe("ConnectableContramap") {
            var connectable: AnyConnectable<String, String>!
            var contramapped: AnyConnectable<Int, String>!

            let map = { (int: Int) -> String in
                "\(int)"
            }

            var output: String?
            let outputHandler = { (string: String) in
                output = string
            }

            var disposed = false
            let dispose = {
                disposed = true
            }

            beforeEach {
                connectable = AnyConnectable({ (consumer: @escaping Consumer<String>) -> Connection<String> in
                    Connection(acceptClosure: consumer, disposeClosure: dispose)
                })

                contramapped = connectable.contramap(map)
            }

            it("should apply the mapping function to the input and forward the value to the consumer") {
                contramapped.connect(outputHandler).accept(8623)

                expect(output).to(equal("8623"))
            }

            it("should propagate dispose") {
                contramapped.connect(outputHandler).dispose()

                expect(disposed).to(beTrue())
            }
        }
    }
}
