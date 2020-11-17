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
import MobiusThrowableAssertion
import Nimble
import Quick

@testable import MobiusExtras

class ConnectableTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("ConnectableClass") {
            beforeEach {
                MobiusHooks.setErrorHandler { message, file, line in
                    MobiusThrowableAssertion(message: message, file: "\(file)", line: line).throw()
                }
            }

            afterEach {
                MobiusHooks.setDefaultErrorHandler()
            }

            func catchError(in closure: () -> Void) -> Bool {
                let exception = MobiusThrowableAssertion.catch(in: closure)
                return exception != nil
            }

            context("when creating a connection") {
                var sut: SubclassedConnectableClass!
                var connection: Connection<String>!

                beforeEach {
                    sut = SubclassedConnectableClass()
                    connection = sut.connect({ _ in })
                }

                it("should call onConnect") {
                    expect(sut.connectCounter).to(equal(1))
                }

                context("when a connection has already been created") {
                    it("should fail") {
                        let errorThrown = catchError {
                            _ = sut.connect({ _ in })
                        }
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
                        let errorThrown = catchError {
                            connection.dispose()
                            connection.accept("Pointless")
                        }
                        expect(errorThrown).to(beTrue())
                    }
                }
            }

            context("when attempting to send some data back to the loop") {
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
