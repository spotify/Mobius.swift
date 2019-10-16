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

class WorkQueueTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("WorkQueue") {
            var workQueue: WorkQueue!
            var results: [String]!

            beforeEach {
                workQueue = WorkQueue()
                results = []
            }

            // Enqueue a block that appends a given string to the results array
            func enqueue(_ result: String) {
                workQueue.enqueue {
                    results.append(result)
                }
            }

            it("executes enqueued blocks in order") {
                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                workQueue.service()

                expect(results).to(equal(["item 1", "item 2", "item 3"]))
            }

            it("can be serviced multiple times") {
                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                workQueue.service()

                enqueue("item 4")
                enqueue("item 5")

                workQueue.service()

                expect(results).to(equal(["item 1", "item 2", "item 3", "item 4", "item 5"]))
            }

            it("doesn’t perform tasks before service is called") {
                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                workQueue.service()

                enqueue("item 5")
                enqueue("item 6")

                expect(results).to(equal(["item 1", "item 2", "item 3"]))
            }

            it("executes blocks added within a work item during the current service cycle") {
                workQueue.enqueue {
                    enqueue("item 1")
                }

                workQueue.service()

                expect(results).to(equal(["item 1"]))
            }

            it("performs nested work items strictly after ongoing ones") {
                workQueue.enqueue {
                    enqueue("item 3")
                    results.append("item 1")
                    workQueue.service()
                }
                enqueue("item 2")

                workQueue.service()

                expect(results).to(equal(["item 1", "item 2", "item 3"]))
            }
        }
    }
}
