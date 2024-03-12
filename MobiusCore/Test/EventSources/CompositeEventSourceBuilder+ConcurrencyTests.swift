// Copyright 2019-2024 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import MobiusCore
import Nimble
import Quick

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
final class CompositeEventSourceBuilder_ConcurrencyTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("CompositeEventSourceBuilder") {
            var sequence: AsyncStream<String>!
            var elementProducer: AsyncStream<String>.Continuation!

            beforeEach {
                sequence = AsyncStream<String> { continuation in
                    elementProducer = continuation
                }
            }

            context("when configuring the composite event source builder") {
                var compositeEventSource: AnyEventSource<String>!
                var disposable: Disposable!
                var receivedEvents: [String]!

                context("with an AsyncSequence event source") {
                    beforeEach {
                        let sut = CompositeEventSourceBuilder<String>()
                            .addEventSource(sequence, receiveOn: .main)

                        compositeEventSource = sut.build()
                        receivedEvents = []

                        disposable = compositeEventSource.subscribe {
                            receivedEvents.append($0)
                        }
                    }

                    afterEach {
                        disposable.dispose()
                    }

                    it("should receive events from the sequence") {
                        elementProducer.yield("foo")
                        expect(receivedEvents).toEventually(equal(["foo"]))

                        elementProducer.yield("bar")
                        expect(receivedEvents).toEventually(equal(["foo", "bar"]))
                    }
                }
            }

            describe("DelayedSequence") {
                context("MobiusLoop with an AsyncSequence event source") {
                    var loop: MobiusLoop<String, String, String>!
                    var receivedModels: [String]!

                    beforeEach {
                        let effectHandler = EffectRouter<String, String>()
                            .asConnectable

                        let eventSource = CompositeEventSourceBuilder<String>()
                            .addEventSource(sequence, receiveOn: .main)
                            .build()

                        loop = Mobius
                            .loop(update: { _, event in .next(event) }, effectHandler: effectHandler)
                            .withEventSource(eventSource)
                            .start(from: "foo")

                        receivedModels = []
                        loop.addObserver { model in receivedModels.append(model) }
                    }

                    afterEach {
                        loop.dispose()
                    }

                    it("should prevent events from being submitted after dispose") {
                        elementProducer.yield("bar")
                        expect(receivedModels).toEventually(equal(["foo", "bar"]))

                        loop.dispose()

                        elementProducer.yield("baz")
                        expect(receivedModels).toNever(equal(["foo", "bar", "baz"]))
                    }
                }

                context("MobiusController with an AsyncSequence event source") {
                    let loopQueue = DispatchQueue(label: "loop queue")
                    let viewQueue = DispatchQueue(label: "view queue")

                    var controller: MobiusController<String, String, String>!
                    var view: RecordingTestConnectable!

                    beforeEach {
                        let effectHandler = EffectRouter<String, String>()
                            .asConnectable

                        let eventSource = CompositeEventSourceBuilder<String>()
                            .addEventSource(sequence)
                            .build()

                        controller = Mobius
                            .loop(update: { _, event in .next(String(event)) }, effectHandler: effectHandler)
                            .withEventSource(eventSource)
                            .makeController(from: "foo", loopQueue: loopQueue, viewQueue: viewQueue)

                        view = RecordingTestConnectable(expectedQueue: viewQueue)
                        controller.connectView(view)
                    }

                    it("should prevent events from being submitted after dispose") {
                        controller.start()

                        elementProducer.yield("bar")
                        expect(view.recorder.items).toEventually(equal(["foo", "bar"]))

                        controller.stop()

                        elementProducer.yield("baz")
                        expect(view.recorder.items).toNever(equal(["foo", "bar", "baz"]))
                    }
                }
            }
        }
    }
}
