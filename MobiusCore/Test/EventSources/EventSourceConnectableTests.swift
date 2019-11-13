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
import MobiusCore
import Nimble
import Quick

class EventSourceConnectableTests: QuickSpec {
    override func spec() {
        let queue = DispatchQueue.testQueue("Event Queue")

        context("") {
            var receivedEvents: [String]!
            var testEventSource: TestEventSource!
            var loop: Disposable!
            func update(model: String, event: String) -> Next<String, String> {
                receivedEvents.append(event)
                return .next(event)
            }
            beforeEach {
                receivedEvents = []
                testEventSource = TestEventSource()
                loop = Mobius.loop(update: update, effectHandler: noOpEffectHandler)
                    .withEventSourceConnectable(testEventSource.asConnectable)
                    .withEventQueue(queue)
                    .start(from: "1")
            }

            afterEach {
                loop.dispose()
            }

            it("Should call the event source with the model that the loop was started from") {
                queue.waitForOutstandingTasks()

                expect(testEventSource.receivedModels).to(equal(["1"]))
            }

            it("Should send all updates of the model to the event source") {
                testEventSource.sendEvent?("2")
                testEventSource.sendEvent?("3")

                queue.waitForOutstandingTasks()

                expect(testEventSource.receivedModels).to(equal(["1", "2", "3"]))
            }

            it("Should send all evernts from the event source to the update function") {
                testEventSource.sendEvent?("2")
                testEventSource.sendEvent?("3")

                queue.waitForOutstandingTasks()

                expect(receivedEvents).to(equal(["2", "3"]))
            }

            it("Should dispose the event source when the loop is disposed") {
                expect(testEventSource.isDisposed).to(beFalse())
                loop.dispose()
                expect(testEventSource.isDisposed).to(beTrue())
            }
        }
    }
}

private let noOpEffectHandler = EffectRouter<String, String>()
    .routeEffects(matching: { _ in true }).to { _ in }
    .asConnectable

private class TestEventSource {
    var receivedModels: [String] = []
    var sendEvent: Consumer<String>?
    var isDisposed: Bool {
        return sendEvent == nil
    }

    lazy var asConnectable: AnyConnectable<String, String> =
        EffectRouter<String, String>()
            .routeEffects(matching: { _ in true })
            .to(effectHandler)
            .asConnectable

    private lazy var effectHandler = EffectHandler<String, String>(
        handle: { model, dispatch in
            self.receivedModels.append(model)
            self.sendEvent = dispatch
        },
        disposable: AnonymousDisposable {
            self.sendEvent = nil
        }
    )
}
