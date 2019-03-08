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

class MergedEventSourceTests: QuickSpec {
    override func spec() {
        describe("MergedEventSource") {
            var sut: MergedEventSource<Int>!

            context("when initialising the composite event source") {
                context("with a number of event sources") {
                    var eventSources: [TestEventSource]!
                    var consumer: Consumer<Int>!
                    var eventReceived: [Int]?
                    var disposable: Disposable!

                    beforeEach {
                        eventReceived = []

                        consumer = { (event: Int) in
                            eventReceived?.append(event)
                        }

                        eventSources = [TestEventSource(), TestEventSource()]
                        sut = MergedEventSource(eventSources: eventSources)

                        disposable = sut.subscribe(consumer: consumer)
                    }
                    it("should produce an event source that ommits the events from all sources") {
                        var currentEvent = 1
                        eventSources.forEach({ eventSource in
                            eventSource.dispatch(currentEvent)
                            currentEvent += 1
                        })

                        let expectedEvents = [1, 2]
                        expect(eventReceived).to(equal(expectedEvents))
                    }

                    it("should return a disposable that disposes of all the event sources") {
                        disposable.dispose()

                        eventSources.forEach({ (eventSource: TestEventSource) in
                            expect(eventSource.isDisposed).to(beTrue())
                        })
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
