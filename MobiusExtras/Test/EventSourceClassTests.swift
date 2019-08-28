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

class EventSourceClassTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("EventSourceClass") {
            var errorThrown: Bool = false
            let handleError = { (_: String) -> Void in
                errorThrown = true
            }

            beforeEach {
                errorThrown = false
            }

            context("when attempting to use the base class directly") {
                var sut: EventSourceClass<String>!

                beforeEach {
                    sut = EventSourceClass()
                    sut.handleError = handleError
                }

                context("when attempting to use onSubscribe") {
                    it("should cause a mobius error") {
                        sut.onSubscribe()
                        expect(errorThrown).to(beTrue())
                    }
                }

                context("when attempting to use onDispose") {
                    it("should cause a mobius error") {
                        sut.onDispose()
                        expect(errorThrown).to(beTrue())
                    }
                }
            }

            context("when attempting to send some data back to the loop") {
                var sut: SubclassedEventSourceClass!
                var consumer: Consumer<String>!

                beforeEach {
                    sut = SubclassedEventSourceClass()
                    sut.handleError = handleError
                }

                context("when consumer is set") {
                    it("should be called") {
                        var data: String?
                        consumer = { consumerData in
                            data = consumerData
                        }
                        _ = sut.subscribe(consumer: consumer)
                        sut.send("Something")
                        expect(data).to(equal("Something"))
                    }
                }

                context("when consumer is not set") {
                    it("should cause a mobius error") {
                        sut.send("Something")
                        expect(errorThrown).to(beTrue())
                    }
                }
            }

            context("when connecting to the loop") {
                var sut: SubclassedEventSourceClass!

                beforeEach {
                    sut = SubclassedEventSourceClass()
                    sut.handleError = handleError
                }

                context("when subscribe") {
                    it("should call on subscribe") {
                        _ = sut.subscribe(consumer: { _ in })
                        expect(sut.subscribeCounter).to(equal(1))
                    }
                }

                context("when disposed") {
                    it("should call on subscribe") {
                        let disposable = sut.subscribe(consumer: { _ in })
                        disposable.dispose()
                        expect(sut.disposeCounter).to(equal(1))
                    }
                }
            }
        }
    }
}

// A class used to make sure that the EventSourceClass behaves correctly.
private class SubclassedEventSourceClass: EventSourceClass<String> {
    var subscribeCounter = 0
    override func onSubscribe() {
        subscribeCounter += 1
    }

    var disposeCounter = 0
    override func onDispose() {
        disposeCounter += 1
    }
}
