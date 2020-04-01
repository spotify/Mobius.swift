// Copyright (c) 2020 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

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
                connectable = AnyConnectable<String, String>({ (consumer: @escaping Consumer<String>) -> Connection<String> in
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
