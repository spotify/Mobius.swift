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

class AnyEventSourceTests: QuickSpec {
    override func spec() {
        describe("AnyEventSource") {
            var eventConsumer: TestConsumer!
            var delegateEventSource: TestEventSource!

            beforeEach {
                eventConsumer = TestConsumer()
                delegateEventSource = TestEventSource()
            }

            it("should forward delegate consumer to closure") {
                let consumerForwarded = self.expectation(description: "consumer forwarded")

                let source = AnyEventSource<String>({ consumer in
                    let testString = UUID().uuidString
                    consumer(testString)
                    if eventConsumer.received == [testString] {
                        consumerForwarded.fulfill()
                    }
                    return TestDisposable()
                })

                _ = source.subscribe(consumer: eventConsumer.accept)
            }

            it("should forward events from delegate event source") {
                let source = AnyEventSource(delegateEventSource)

                _ = source.subscribe(consumer: eventConsumer.accept)

                delegateEventSource.produce(value: "a value")

                expect(eventConsumer.received).to(equal(["a value"]))
            }

            it("should forward dispose to disposable from delegate closure") {
                let disposable = TestDisposable()
                let actualDisposable = AnyEventSource<String>({ _ in disposable }).subscribe(consumer: eventConsumer.accept)

                actualDisposable.dispose()

                expect(disposable.disposed).to(beTrue())
            }

            it("should forward dispose to disposable from delegate event source") {
                let actualDisposable = AnyEventSource(delegateEventSource).subscribe(consumer: eventConsumer.accept)

                actualDisposable.dispose()

                expect(delegateEventSource.disposed).to(beTrue())
            }
        }
    }
}

private class TestConsumer {
    var received = [String]()

    func accept(_ value: String) {
        received.append(value)
    }
}

private class TestEventSource: EventSource {
    typealias Event = String

    var consumer: Consumer<String>?
    var disposed = false

    func subscribe(consumer: @escaping Consumer<String>) -> Disposable {
        guard self.consumer == nil else {
            fatalError("subscribed twice to the same event source")
        }

        self.consumer = consumer

        return AnonymousDisposable(disposer: { () in self.disposed = true })
    }

    func produce(value: String) {
        consumer!(value)
    }
}
