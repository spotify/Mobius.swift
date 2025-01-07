// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore
import Nimble
import Quick

class CompositeEventSourceBuilderTest: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        var eventsReceived: [Int]!
        var compositeEventSource: AnyEventSource<Int>!
        var disposable: Disposable!

        describe("CompositeEventSourceBuilder") {
            context("when configuring the composite event source builder") {
                context("with no event sources") {
                    beforeEach {
                        let sut = CompositeEventSourceBuilder<Int>()
                        compositeEventSource = sut.build()
                        eventsReceived = []
                    }

                    it("should produce an event source") {
                        // In particular, we want a do-nothing event source rather than an assertion or crash.
                        disposable = compositeEventSource.subscribe {
                            eventsReceived.append($0)
                        }
                        disposable.dispose()

                        expect(eventsReceived).to(equal([]))
                    }
                }

                context("with one event source") {
                    var eventSource: TestEventSource<Int>!

                    beforeEach {
                        eventSource = TestEventSource()
                        let sut = CompositeEventSourceBuilder<Int>()
                            .addEventSource(eventSource)

                        compositeEventSource = sut.build()
                        eventsReceived = []

                        disposable = compositeEventSource.subscribe {
                            eventsReceived.append($0)
                        }
                    }

                    it("should provide an event source equivalent to the input event source") {
                        eventSource.dispatch(1)
                        eventSource.dispatch(2)

                        let expectedEvents = [1, 2]
                        expect(eventsReceived).to(equal(expectedEvents))
                    }

                    it("should return a disposable that disposes the original event source") {
                        disposable?.dispose()

                        expect(eventSource.allDisposed).to(beTrue())
                    }
                }

                context("with several event sources") {
                    var eventSources: [TestEventSource<Int>]!

                    beforeEach {
                        eventSources = [TestEventSource(), TestEventSource(), TestEventSource()]
                        var sut = CompositeEventSourceBuilder<Int>()
                        eventSources.forEach {
                            sut = sut.addEventSource($0)
                        }

                        compositeEventSource = sut.build()
                        eventsReceived = []

                        disposable = compositeEventSource.subscribe {
                            eventsReceived.append($0)
                        }
                    }

                    it("should produce an event source that emits the events from all input sources") {
                        eventSources.enumerated().forEach { index, source in
                            source.dispatch(index)
                        }

                        let expectedEvents = [0, 1, 2]
                        expect(eventsReceived).to(equal(expectedEvents))
                    }

                    it("should return a disposable that disposes of all the input event sources") {
                        disposable?.dispose()

                        eventSources.forEach {
                            expect($0.allDisposed).to(beTrue())
                        }
                    }
                }
            }
        }
    }
}
