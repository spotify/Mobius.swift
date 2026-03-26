// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import MobiusCore
import Nimble
import Quick

class AnyEventSourceTests: QuickSpec {
    override class func spec() {
        describe("AnyEventSource") {
            var eventConsumer: TestConsumer!
            var delegateEventSource: TestEventSource<String>!

            beforeEach {
                eventConsumer = TestConsumer()
                delegateEventSource = TestEventSource()
            }

            it("should forward delegate consumer to closure") {
                var forwarded = false

                let source = AnyEventSource<String>({ consumer in
                    let testString = UUID().uuidString
                    consumer(testString)
                    if eventConsumer.received == [testString] {
                        forwarded = true
                    }
                    return TestDisposable()
                })

                _ = source.subscribe(consumer: eventConsumer.accept)
                expect(forwarded).toEventually(beTrue())
            }

            it("should forward events from delegate event source") {
                let source = AnyEventSource(delegateEventSource)

                _ = source.subscribe(consumer: eventConsumer.accept)

                delegateEventSource.dispatch("a value")

                expect(eventConsumer.received).to(equal(["a value"]))
            }

            it("should forward dispose to disposable from delegate closure") {
                let disposable = TestDisposable()
                let actualDisposable = AnyEventSource<String>({ _ in disposable }).subscribe(consumer: eventConsumer.accept)

                actualDisposable.dispose()

                expect(disposable.disposed).to(beTrue())
            }

            it("should forward dispose to disposable from delegate event source") {
                let actualDisposable = AnyEventSource(delegateEventSource).subscribe(consumer: eventConsumer.accept)

                actualDisposable.dispose()

                expect(delegateEventSource.allDisposed).to(beTrue())
            }
        }
    }
}

private class TestConsumer {
    var received = [String]()

    func accept(_ value: String) {
        received.append(value)
    }
}
