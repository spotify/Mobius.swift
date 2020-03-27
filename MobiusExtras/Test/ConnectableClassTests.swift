// Copyright (c) 2019 Spotify AB.
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
import Nimble
import Quick

@testable import MobiusExtras

class ConnectableTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("ConnectableClass") {
            var errorThrown: Bool = false
            let handleError = { (_: String) -> Void in
                errorThrown = true
            }

            beforeEach {
                errorThrown = false
            }

            context("when attempting to use the base class directly") {
                var sut: ConnectableClass<String, String>!

                beforeEach {
                    sut = ConnectableClass()
                    sut.handleError = handleError
                }

                context("when attempting to use handle") {
                    it("should cause a mobius error") {
                        sut.handle("something")
                        expect(errorThrown).to(beTrue())
                    }
                }

                context("when attempting to use disposed") {
                    it("should cause a mobius error") {
                        sut.onDispose()
                        expect(errorThrown).to(beTrue())
                    }
                }
            }

            context("when creating a connection") {
                var sut: SubclassedConnectableClass!
                var connection: Connection<String>!

                beforeEach {
                    sut = SubclassedConnectableClass()
                    connection = sut.connect({ _ in })
                    sut.handleError = handleError
                }

                it("should call onConnect") {
                    expect(sut.connectCounter).to(equal(1))
                }

                context("when a connection has already been created") {
                    it("should fail") {
                        _ = sut.connect({ _ in })
                        expect(errorThrown).to(beTrue())
                    }
                }

                context("when some input is sent") {
                    it("should call handle in the subclass with the input") {
                        let testData = "a string"
                        connection.accept(testData)
                        expect(sut.handledStrings).to(equal([testData]))
                    }
                }

                context("when dispose is called") {
                    it("should call onDispose in the subclass") {
                        connection.dispose()
                        expect(sut.disposeCounter).to(equal(1))
                    }

                    it("should have removed the consumer") {
                        connection.dispose()
                        connection.accept("Pointless")
                        expect(errorThrown).to(beTrue())
                    }
                }
            }

            context("when attempting to send some data back to the loop") {
                context("when the consumer is not set") {
                    var sut: SubclassedConnectableClass!
                    beforeEach {
                        sut = SubclassedConnectableClass()
                        sut.handleError = handleError
                    }

                    xit("should cause a mobius error") {
                        sut.send("Some string")
                        expect(errorThrown).to(beTrue())
                    }
                }

                context("when the consumer is set") {
                    var sut: SubclassedConnectableClass!
                    var consumerReceivedData: String?
                    beforeEach {
                        sut = SubclassedConnectableClass()
                        _ = sut.connect({ (data: String) in
                            consumerReceivedData = data
                        })
                    }

                    it("should send that data to the consumer") {
                        let testData = "some data"
                        sut.send(testData)
                        expect(consumerReceivedData).to(equal(testData))
                    }
                }
            }
        }
    }
}

// A class used to make sure that the ConnectableClass behaves correctly with regards to accepting data and
// disposing of the connection
private class SubclassedConnectableClass: ConnectableClass<String, String> {
    var handledStrings = [String]()
    override func handle(_ input: String) {
        handledStrings.append(input)
    }

    var connectCounter = 0
    override func onConnect() {
        connectCounter += 1
    }

    var disposeCounter = 0
    override func onDispose() {
        disposeCounter += 1
    }
}
