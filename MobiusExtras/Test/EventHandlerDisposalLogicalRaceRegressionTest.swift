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
import MobiusExtras
import Nimble
import Quick

struct Model {}

private enum Event {
    case event1
    case event2
}

private enum Effect {
    case effect1
}

/// This is a regression test for a set of threading issues in Mobius 0.2. It would fail in two different ways:
///
/// First, by stopping a controller/disposing a loop immediately after dispatching an event, we would consistently hit
/// "cannot accept values when disposed" in ConnectablePublisher.post.
///
/// Second, after disabling or working around that test, we would hit a fatal error in ConnectableClass: "EffectHandler
/// is unable to send Event before any consumer has been set. Send should only be used once the Connectable has been
/// properly connected."
///
/// We had seen small volumes of this second issue in production. (Spotify internal: IOS-42623)
class EventHandlerDisposalLogicalRaceRegressionTest: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("Effect Handler connection") {
            var controller: MobiusController<Model, Event, Effect>!
            var effectHandler: EffectHandler!
            var errorThrown: Bool!
            var eventSource: TestEventSource!

            beforeEach {
                effectHandler = EffectHandler()
                eventSource = TestEventSource()

                errorThrown = false
                MobiusHooks.setErrorHandler({ _, _, _ in
                    errorThrown = true
                })

                let update = Update<Model, Event, Effect> { _, _ in [.effect1] }

                controller = Mobius.loop(update: update, effectHandler: effectHandler)
                    .withEventSource(eventSource)
                    .makeController(from: Model())

                controller.connectView(ActionConnectable {})
            }

            afterEach {
                MobiusHooks.setDefaultErrorHandler()
            }

            it("allows stopping a loop immediately after dispatching an event") {
                controller.start()
                eventSource.dispatchEvent(.event1)
                controller.stop()
                expect(errorThrown).to(beFalse())
            }
        }
    }
}

private class EffectHandler: ConnectableClass<Effect, Event>, EffectPredicate {
    func canAccept(_ effect: Effect) -> Bool {
        return true
    }

    private let collaborator = EffectCollaborator()
    private var cancellationToken: CancellationToken?

    override func handle(_ effect: Effect) {
        cancellationToken?.cancel()

        cancellationToken = collaborator.asyncDoStuff { [weak self] in
            self?.complete()
        }
    }

    func complete() {
        self.send(.event2)
    }

    override func onDispose() {
        cancellationToken = nil
    }

    typealias Effect = InputType
}

// Stand-in for an object that does something asynchronous and cancellable, e.g. fetch data.
private class EffectCollaborator {
    func asyncDoStuff(completion closure: @escaping () -> Void) -> CancellationToken {
        let cancelLock = DispatchQueue(label: "Cancel lock")
        var cancelled = false

        DispatchQueue.global().asyncAfter(deadline: .now()) {
            if !cancelLock.sync { cancelled } {
                closure()
            }
        }

        return CancellationToken {
            cancelLock.sync { cancelled = true }
        }
    }
}

final class CancellationToken {
    private var callback: (() -> Void)?

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func cancel() {
        let cb = callback
        callback = nil
        cb?()
    }
}

// Trivial event source that lets us inject events
private class TestEventSource: EventSource {
    private var consumer: Consumer<Event>?

    func subscribe(consumer: @escaping Consumer<Event>) -> Disposable {
        self.consumer = consumer

        return AnonymousDisposable {
            self.consumer = nil
        }
    }

    func dispatchEvent(_ event: Event) {
        consumer!(event)
    }
}
