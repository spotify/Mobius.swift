// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import MobiusExtras
import Nimble
import Quick

class EventSourceExtensionsTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("EventSource") {
            var subscribedIntConsumer: ((Int) -> Void)?
            var intEventSource: AnyEventSource<Int>!

            beforeEach {
                intEventSource = AnyEventSource { (consumer: @escaping (Int) -> Void) in
                    subscribedIntConsumer = consumer
                    return AnonymousDisposable {}
                }
            }

            context("when mapping the event source from one type to another") {
                var stringEventSource: AnyEventSource<String>!

                beforeEach {
                    stringEventSource = intEventSource.map { integer in "\(integer)" }
                }

                it("it creates a new event source, which translates and forwards events from the original one") {
                    var emittedStringEvents: [String] = []
                    _ = stringEventSource.subscribe { string in emittedStringEvents.append(string) }

                    subscribedIntConsumer?(12)
                    expect(emittedStringEvents).to(equal(["12"]))
                }
            }
        }
    }
}
