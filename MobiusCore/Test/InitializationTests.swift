// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import MobiusCore
import Nimble
import Quick

class InitializationTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("Initialization") {
            var builder: Mobius.Builder<String, String, String>!
            var updateFunction: Update<String, String, String>!
            var loop: MobiusLoop<String, String, String>!
            var receivedModels: [String]!
            var modelObserver: Consumer<String>!
            var effectHandler: RecordingTestConnectable!
            var eventSource: TestEventSource<String>!
            var connectableEventSource: TestConnectableEventSource<String, String>!

            beforeEach {
                receivedModels = []

                modelObserver = { receivedModels.append($0) }

                updateFunction = Update<String, String, String> { _, event in
                    if event == "event that triggers effect" {
                        return Next.next(event, effects: [event])
                    } else {
                        return Next.next(event)
                    }
                }

                effectHandler = RecordingTestConnectable()
                eventSource = TestEventSource()
                connectableEventSource = .init()

            }

            it("should process init") {
                builder = Mobius.loop(update: updateFunction, effectHandler: effectHandler)

                loop = builder.start(from: "the first model")

                loop.addObserver(modelObserver)

                expect(receivedModels).to(equal(["the first model"]))
            }

            it("should process init and then events") {
                builder = Mobius.loop(update: updateFunction, effectHandler: effectHandler)

                loop = builder.start(from: "the first model")

                loop.addObserver(modelObserver)
                loop.dispatchEvent("event that triggers effect")

                expect(receivedModels).to(equal(["the first model", "event that triggers effect"]))
            }

            it("should process init before events from connectable event source") {
                builder = Mobius.loop(update: updateFunction, effectHandler: effectHandler)
                    .withEventSource(connectableEventSource)

                connectableEventSource.dispatch("ignored event from connectable event source")
                loop = builder.start(from: "the first model")
                loop.addObserver(modelObserver)

                connectableEventSource.dispatch("second event from connectable event source")

                // The first event was sent before the loop started so it should be ignored. The second should go through
                expect(receivedModels).to(equal(["the first model", "second event from connectable event source"]))
            }

            it("should process init before events from event source") {
                builder = Mobius.loop(update: updateFunction, effectHandler: effectHandler)
                    .withEventSource(eventSource)

                eventSource.dispatch("ignored event from event source")
                loop = builder.start(from: "the first model")
                loop.addObserver(modelObserver)

                eventSource.dispatch("second event from event source")

                // The first event was sent before the loop started so it should be ignored. The second should go through
                expect(receivedModels).to(equal(["the first model", "second event from event source"]))
            }
        }
    }
}

// Emits values before returning the connection
class EagerTestConnectable: Connectable {
    private(set) var consumer: Consumer<String>?
    private(set) var recorder: Recorder<String>
    private(set) var eagerValue: String

    private(set) var connection: Connection<String>!

    init(eagerValue: String) {
        self.recorder = Recorder()
        self.eagerValue = eagerValue
    }

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        self.consumer = consumer
        connection = Connection(acceptClosure: accept, disposeClosure: dispose) // Will retain self
        connection.accept(eagerValue) // emit before returning
        return connection
    }

    func dispatch(_ string: String) {
        consumer?(string)
    }

    func accept(_ value: String) {
        recorder.append(value)
    }

    func dispose() {
    }
}
