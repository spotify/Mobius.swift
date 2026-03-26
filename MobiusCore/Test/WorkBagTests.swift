// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore
import Nimble
import Quick

class WorkBagTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("WorkBag") {
            var workBag: WorkBag!
            var results: Set<String>!

            beforeEach {
                workBag = WorkBag()
                results = []
            }

            // Enqueue a block that adds a given string to the results set
            func enqueue(_ result: String) {
                workBag.submit {
                    results.insert(result)
                }
            }

            it("executes enqueued blocks in order") {
                workBag.start()

                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                workBag.service()

                expect(results).to(equal(["item 1", "item 2", "item 3"]))
            }

            it("enqueues but does not execute blocks submitted before start()") {
                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                expect(results).to(equal([]))

                workBag.start()

                expect(results).to(equal(["item 1", "item 2", "item 3"]))
            }

            it("can be serviced multiple times") {
                workBag.start()

                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                workBag.service()

                enqueue("item 4")
                enqueue("item 5")

                workBag.service()

                expect(results).to(equal(["item 1", "item 2", "item 3", "item 4", "item 5"]))
            }

            it("doesn’t perform tasks before service is called") {
                workBag.start()

                enqueue("item 1")
                enqueue("item 2")
                enqueue("item 3")

                workBag.service()

                enqueue("item 5")
                enqueue("item 6")

                expect(results).to(equal(["item 1", "item 2", "item 3"]))
            }

            it("executes blocks added within a work item during the current service cycle") {
                workBag.start()

                workBag.submit {
                    enqueue("item 1")
                }

                workBag.service()

                expect(results).to(equal(["item 1"]))
            }

            it("performs nested work items strictly after ongoing ones") {
                workBag.start()

                // Note that here results is an array rather than a set
                var results = [String]()

                workBag.submit {
                    workBag.submit {
                        results.append("item 2")
                    }
                    results.append("item 1")
                    workBag.service()
                }

                workBag.service()

                expect(results).to(equal(["item 1", "item 2"]))
            }
        }
    }
}
