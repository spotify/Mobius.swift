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

import Foundation
import Nimble
import Quick

// swiftlint:disable type_body_length file_length

class MobiusControllerTests: QuickSpec {
    let loopQueue = DispatchQueue(label: "loop queue")
    let viewQueue = DispatchQueue(label: "view queue")

    // swiftlint:disable function_body_length
    override func spec() {
        describe("MobiusController") {
            var controller: MobiusController<String, String, String>!
            var view: RecordingTestConnectable!
            var eventSource: TestEventSource<String>!
            var errorThrown: Bool!

            func clearViewRecorder() {
                makeSureAllEffectsAndEventsHaveBeenProccessed()
                view.recorder.clear()
            }

            beforeEach {
                view = RecordingTestConnectable(expectedQueue: self.viewQueue)
                let loopQueue = self.loopQueue

                let updateFunction = Update<String, String, String>.create { model, event in
                    dispatchPrecondition(condition: .onQueue(loopQueue))
                    return .next("\(model)-\(event)")
                }

                eventSource = TestEventSource()

                controller = Mobius.loop(update: updateFunction, effectHandler: SimpleTestConnectable())
                    .withEventSource(eventSource)
                    .makeController(from: "S", loopQueue: self.loopQueue, viewQueue: self.viewQueue)

                errorThrown = false
                MobiusHooks.setErrorHandler({ _, _, _ in
                    errorThrown = true
                })
            }

            afterEach {
                MobiusHooks.setDefaultErrorHandler()
            }

            describe("connecting") {
                describe("happy cases") {
                    it("should allow connecting before starting") {
                        controller.connectView(view)
                        controller.start()

                        expect(view.recorder.items).toEventually(equal(["S"]))
                    }
                    it("should hook up the view's events to the loop") {
                        controller.connectView(view)
                        controller.start()

                        view.dispatch("hey")

                        expect(view.recorder.items).toEventually(equal(["S", "S-hey"]))
                    }

                    context("given a connected and started loop") {
                        beforeEach {
                            controller.connectView(view)
                            controller.start()

                            clearViewRecorder()
                        }
                        it("should allow stopping and starting again") {
                            controller.stop()
                            controller.start()
                        }
                        it("should send new models to the view") {
                            controller.stop()
                            controller.start()

                            view.dispatch("restarted")
                            self.makeSureAllEffectsAndEventsHaveBeenProccessed()

                            expect(view.recorder.items).toEventually(equal(["S", "S-restarted"]))
                        }
                        it("should retain updated state") {
                            view.dispatch("hi")
                            self.makeSureAllEffectsAndEventsHaveBeenProccessed()

                            controller.stop()

                            clearViewRecorder()

                            controller.start()

                            view.dispatch("restarted")

                            expect(view.recorder.items).toEventually(equal(["S-hi", "S-hi-restarted"]))
                        }
                        it("should indicate the running status") {
                            controller.stop()
                            expect(controller.running).to(beFalse())

                            controller.start()
                            expect(controller.running).to(beTrue())
                        }
                    }
                }

                describe("disposing connections") {
                    var modelObserver: MockConnectable!
                    var effectObserver: MockConnectable!
                    var controller: MobiusController<String, String, String>!

                    beforeEach {
                        modelObserver = MockConnectable()
                        effectObserver = MockConnectable()
                        controller = Mobius.loop(update: Update { _, _ in [] }, effectHandler: effectObserver)
                            .makeController(from: "")
                        controller.connectView(modelObserver)
                        controller.start()
                    }

                    it("Should dispose any listeners of the model") {
                        controller.stop()
                        expect(modelObserver.disposed).toEventually(beTrue())
                    }

                    it("Should dispose any effect handlers") {
                        controller.stop()
                        expect(effectObserver.disposed).to(beTrue())
                    }
                }

                describe("error handling") {
                    it("should not allow connecting twice") {
                        controller.connectView(view)
                        controller.connectView(view)

                        expect(errorThrown).to(beTrue())
                    }
                    it("should not allow connecting after starting") {
                        controller.connectView(view)
                        controller.start()
                        controller.connectView(view)

                        expect(errorThrown).to(beTrue())
                    }
                }
            }

            describe("disconnecting") {
                describe("happy cases") {
                    it("should allow disconnecting before starting") {
                        controller.connectView(view)
                        controller.disconnectView()
                    }
                    it("should allow disconnecting after stopping") {
                        controller.connectView(view)
                        controller.start()
                        controller.stop()
                        controller.disconnectView()
                    }
                    it("should allow reconnecting after disconnecting") {
                        controller.connectView(view)
                        controller.disconnectView()
                        controller.connectView(view)
                        controller.start()

                        expect(view.recorder.items).toEventually(equal(["S"]))
                    }
                    it("should not send events to a disconnected view") {
                        let disconnectedView = RecordingTestConnectable()
                        controller.connectView(disconnectedView)
                        controller.disconnectView()

                        controller.connectView(view)
                        controller.start()

                        expect(view.recorder.items).toEventually(equal(["S"]))
                        expect(disconnectedView.recorder.items).to(beEmpty())
                    }
                    it("should not allow disconnecting before stopping") {
                        controller.connectView(view)
                        controller.start()

                        controller.disconnectView()
                        expect(errorThrown).to(beTrue())
                    }
                }

                #if arch(x86_64) || arch(arm64)
                describe("error handling") {
                    it("should not allow disconnecting while running") {
                        controller.start()
                        controller.disconnectView()

                        expect(errorThrown).to(beTrue())
                    }
                    it("should not allow disconnecting without a connection") {
                        controller.disconnectView()
                        controller.disconnectView()

                        expect(errorThrown).to(beTrue())
                    }
                }
                #endif
            }
            describe("starting and stopping") {
                describe("happy cases") {
                    it("should allow starting a stopping a connected controller") {
                        controller.connectView(view)
                        controller.start()
                        controller.stop()
                    }
                    xit("should allow dispatching an event from the event source immediately") {
                        controller.connectView(view)
                        eventSource.dispatchOnSubscribe("startup")
                        controller.start()
                        controller.stop()

                        expect(view.recorder.items).toEventually(equal(["S", "S-startup"]))
                        expect(errorThrown).to(beFalse())
                    }
                }
                #if arch(x86_64) || arch(arm64)
                describe("error handling") {
                    it("should not allow starting initially") {
                        controller.start()
                        expect(errorThrown).to(beTrue())
                    }
                    it("should not allow starting a running controller") {
                        controller.connectView(view)
                        controller.start()
                        controller.start()

                        expect(errorThrown).to(beTrue())
                    }
                    it("should not allow stopping a loop before connecting") {
                        controller.stop()
                        expect(errorThrown).to(beTrue())
                    }
                    it("should not allow stopping a stopped controller") {
                        controller.connectView(view)
                        controller.start()
                        controller.stop()
                        controller.stop()

                        expect(errorThrown).to(beTrue())
                    }
                }
                #endif
            }
            describe("accessing the model") {
                describe("happy cases") {
                    it("should return the default model before starting") {
                        expect(controller.model).to(equal("S"))
                    }
                    it("should read the model from a running loop") {
                        controller.connectView(view)
                        controller.start()

                        view.dispatch("an event")

                        expect(controller.model).toEventually(equal("S-an event"))
                    }
                    it("should read the last loop model after stopping") {
                        controller.connectView(view)
                        controller.start()

                        view.dispatch("the last event")

                        // wait for event to be processed
                        expect(view.recorder.items).toEventually(equal(["S", "S-the last event"]))

                        controller.stop()

                        expect(controller.model).to(equal("S-the last event"))
                    }
                    it("should start from the last loop model on restart") {
                        controller.connectView(view)
                        controller.start()

                        view.dispatch("the last event")
                        self.makeSureAllEffectsAndEventsHaveBeenProccessed()

                        controller.stop()

                        clearViewRecorder()

                        controller.start()

                        expect(view.recorder.items).toEventually(equal(["S-the last event"]))
                    }
                    it("should support replacing the model when stopped") {
                        controller.connectView(view)

                        controller.replaceModel("R")

                        controller.start()

                        expect(view.recorder.items).toEventually(equal(["R"]))
                    }
                }
                #if arch(x86_64) || arch(arm64)
                describe("error handling") {
                    it("should not allow replacing the model when running") {
                        controller.connectView(view)
                        controller.start()
                        controller.replaceModel("nononono")

                        expect(errorThrown).to(beTrue())
                    }
                }
                #endif
            }

            describe("dispatching events") {
                beforeEach {
                    controller.connectView(view)
                    controller.start()
                }

                it("should dispatch events from the event source") {
                    eventSource.dispatch("event source event")

                    expect(view.recorder.items).toEventually(equal(["S", "S-event source event"]))
                }
            }
        }
    }

    func makeSureAllEffectsAndEventsHaveBeenProccessed() {
        loopQueue.sync {
            // Waiting synchronously for effects to be completed
        }

        viewQueue.sync {
            // Waiting synchronously for view observations to be completed
        }
    }
}

class MockConnectable: Connectable {
    typealias InputType = String
    typealias OutputType = String

    var disposed = false

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        return Connection(acceptClosure: { _ in }, disposeClosure: { self.disposed = true })
    }
}
