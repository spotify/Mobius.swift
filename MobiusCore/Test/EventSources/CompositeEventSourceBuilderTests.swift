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

@testable import MobiusCore
import Nimble
import Quick

class CompositeEventSourceBuilderTest: QuickSpec {
    // swiftlint:disable function_body_length
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
                    var eventSource: TestEventSource!

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

                        expect(eventSource.isDisposed).to(beTrue())
                    }
                }

                context("with several event sources") {
                    var eventSources: [TestEventSource]!

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
                            expect($0.isDisposed).to(beTrue())
                        }
                    }
                }
            }
        }
    }
}

private class TestEventSource: EventSource, Disposable {
    typealias Event = Int

    var consumer: Consumer<Int>?
    func subscribe(consumer: @escaping Consumer<Int>) -> Disposable {
        self.consumer = consumer
        return self
    }

    var isDisposed = false
    func dispose() {
        isDisposed = true
    }

    func dispatch(_ event: Int) {
        consumer?(event)
    }
}
