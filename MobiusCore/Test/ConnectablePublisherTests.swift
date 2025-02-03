// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class ConnectablePublisherTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("ConnectablePublisher") {
            var publisher: ConnectablePublisher<String>!
            var received: [String]!
            var consumer: Consumer<String>!

            beforeEach {
                publisher = ConnectablePublisher()
                received = []

                consumer = {
                    received.append($0)
                }
            }

            describe("connections") {
                it("should forward values to a single connection") {
                    publisher.connect(to: consumer)

                    publisher.post("hey there")

                    expect(received).to(equal(["hey there"]))
                }

                it("should post the current value to new observer") {
                    publisher.post("current")

                    publisher.connect(to: consumer)

                    expect(received).to(equal(["current"]))
                }

                context("given multiple connections") {
                    var received2: [String]!
                    var received3: [String]!

                    var consumer2: Consumer<String>!
                    var consumer3: Consumer<String>!

                    var connection2: Connection<String>!

                    beforeEach {
                        received2 = []
                        received3 = []

                        consumer2 = {
                            received2.append($0)
                        }
                        consumer3 = {
                            received3.append($0)
                        }

                        publisher.connect(to: consumer)
                        connection2 = publisher.connect(to: consumer2)
                        publisher.connect(to: consumer3)
                    }

                    it("should support forwarding to multiple connections") {
                        publisher.post("all the things")

                        expect(received).to(equal(["all the things"]))
                        expect(received2).to(equal(["all the things"]))
                        expect(received3).to(equal(["all the things"]))
                    }
                    it("should stop forwarding values to a disposed connection") {
                        publisher.post("for everyone")

                        connection2.dispose()

                        publisher.post("not for number 2")

                        expect(received).to(equal(["for everyone", "not for number 2"]))
                        expect(received2).to(equal(["for everyone"]))
                        expect(received3).to(equal(["for everyone", "not for number 2"]))
                    }
                }
            }

            describe("lifecycle") {
                context("given it is not disposed") {
                    it("should accept connections") {
                        publisher.connect(to: consumer)

                        publisher.post("accepted")

                        expect(received).to(equal(["accepted"]))
                    }

                    it("should accept values") {
                        publisher.post("oki") // should just succeed - there are no observers, so nothing to check
                    }

                    it("should be disposable") {
                        publisher.dispose() // should just succeed
                    }
                }

                context("given it is disposed") {
                    beforeEach {
                        publisher.dispose()
                    }

                    context("when trying to connect") {
                        it("should refuse connections") {
                            expect(_ = publisher.connect(to: consumer)).to(raiseError())
                        }
                    }

                    context("when trying to post") {
                        it("should refuse values") {
                            expect(publisher.post("crashme")).to(raiseError())
                        }
                    }

                    context("when trying to dispose again") {
                        it("should be disposable") {
                            publisher.dispose() // should just succeed
                        }
                    }
                }
            }
        }
    }
}
