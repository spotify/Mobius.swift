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

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class EventProcessorTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("EventProcessor") {
            var eventProcessor: EventProcessor<Int, Int, Int>!
            var nextPublisher: ConnectablePublisher<Next<Int, Int>>!
            var consumer: Consumer<Next<Int, Int>>!
            var receivedModels: [Int]!

            beforeEach {
                nextPublisher = ConnectablePublisher()
                eventProcessor = EventProcessor(update: self.testUpdate, publisher: nextPublisher)

                receivedModels = []
                consumer = {
                    if let model = $0.model {
                        receivedModels.append(model)
                    }
                }

                nextPublisher.connect(to: consumer)
            }

            describe("publishing") {
                it("should post the first to the publisher as a next") {
                    eventProcessor.start(from: First(model: 1, effects: []))

                    expect(receivedModels).to(equal([1]))
                }

                it("should post nexts to the publisher") {
                    eventProcessor.start(from: First(model: 1, effects: []))

                    eventProcessor.accept(10)
                    eventProcessor.accept(200)
                    expect(receivedModels).to(equal([1, 11, 211]))
                }
            }

            describe("current model") {
                it("should initially be empty") {
                    expect(eventProcessor.readCurrentModel()).to(beNil())
                }

                context("given a start from 1") {
                    beforeEach {
                        eventProcessor.start(from: First(model: 1, effects: []))
                    }

                    it("should track the current model from start") {
                        expect(eventProcessor.readCurrentModel()).to(equal(1))
                    }

                    it("should track the current model from updates") {
                        eventProcessor.accept(99)

                        expect(eventProcessor.readCurrentModel()).to(equal(100))
                    }
                }
            }

            it("should queue events until started") {
                eventProcessor.accept(80)
                eventProcessor.accept(400)

                eventProcessor.start(from: First(model: 1, effects: []))

                expect(receivedModels).to(equal([1, 81, 481]))
            }

            it("should dispose publisher on dispose") {
                eventProcessor.dispose()

                expect(nextPublisher.disposed).to(beTrue())
            }

            describe("debug description") {
                context("when the event processor has no model") {
                    it("should produce the appropriate debug description") {
                        let description = String(reflecting: eventProcessor)
                        expect(description).to(equal("Optional(<nil, []>)"))
                    }
                }

                context("when the event processor has a First") {
                    it("should produce the appropriate debug description") {
                        eventProcessor.start(from: First(model: 1, effects: [2, 3]))
                        let description = String(reflecting: eventProcessor)
                        expect(description).to(contain("Optional(<1")) // Due to synced queue its hard to test a processor with events
                    }
                }
            }
        }
    }

    let testUpdate = Update<Int, Int, Int> { model, event in
        model += event
        return []
    }
}
