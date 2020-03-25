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

// Should only test public APIs
class MobiusIntegrationTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("Mobius integration tests") {
            let update = Update<String, String, String> { _, event in
                switch event {
                case "button pushed":
                    return Next.next("pushed")
                case "trigger effect":
                    return Next.next("triggered", effects: ["leads to event"])
                case "effect feedback":
                    return Next.next("done")
                case "from source":
                    return Next.next("event sourced")
                default:
                    fatalError("unexpected event \(event)")
                }
            }

            context("given the loop is started") {
                var loop: MobiusLoop<String, String, String>!
                var eventSourceEventConsumer: Consumer<String>!
                var receivedModels: Recorder<String>!
                var receivedEffects: Recorder<String>!

                beforeEach {
                    let effectHandler = IntegrationTestEffectHandler()
                    receivedEffects = effectHandler.recorder

                    let eventSource = AnyEventSource<String> { consumer in
                        eventSourceEventConsumer = consumer
                        return TestDisposable()
                    }

                    loop = Mobius.loop(update: update, effectHandler: effectHandler)
                        .withEventSource(eventSource)
                        .start(from: "init", effects: ["trigger loading"])

                    receivedModels = Recorder()
                    loop.addObserver { model in
                        receivedModels.append(model)
                    }

                    // clear out startup noise
                    receivedModels.clear()
                    receivedEffects.clear()
                }

                afterEach {
                    loop.dispose()
                    loop = nil
                }

                it("should be possible for the UI to push events and receive models") {
                    loop.dispatchEvent("button pushed")

                    expect(receivedModels.items).to(equal(["pushed"]))
                }

                it("should be possible for effect handler to receive effects and send events") {
                    loop.dispatchEvent("trigger effect")

                    expect(receivedModels.items).toEventually(equal(["triggered", "done"]))
                    expect(receivedEffects.items).to(equal(["leads to event"]))
                }

                it("should be possible for event sources to send events") {
                    eventSourceEventConsumer("from source")

                    expect(receivedModels.items).to(equal(["event sourced"]))
                }
            }
        }
    }
}

private class IntegrationTestEffectHandler: RecordingTestConnectable {
    override func accept(_ value: String) {
        super.accept(value)
        switch value {
        case "leads to event":
            consumer?("effect feedback")
        case "trigger loading":
            break
        default:
            fail("unexpected effect \(value)")
        }
    }
}
