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

import MobiusCore
import MobiusExtras
import Nimble
import Quick

class EventSourceExtensionsTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        describe("EventSource") {
            var subscribedIntConsumer: ((Int) -> Void)?
            var intEventSource: AnyEventSource<Int>!

            beforeEach {
                intEventSource = AnyEventSource { (consumer: @escaping (Int) -> Void) in
                    subscribedIntConsumer = consumer
                    return AnonymousDisposable {}
                }
            }

            context("when mapping the event source from one type to another") {
                var stringEventSource: AnyEventSource<String>!

                beforeEach {
                    stringEventSource = intEventSource.map { integer in "\(integer)" }
                }

                it("it creates a new event source, which translates and forwards events from the original one") {
                    var emittedStringEvents: [String] = []
                    _ = stringEventSource.subscribe { string in emittedStringEvents.append(string) }

                    subscribedIntConsumer?(12)
                    expect(emittedStringEvents).to(equal(["12"]))
                }
            }
        }
    }
}
