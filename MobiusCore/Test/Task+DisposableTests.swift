// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

@available(iOS 13.0, *)
class TaskDisposableTests: QuickSpec {
    override class func spec() {
        describe("Task+Disposable") {
            var task: Task<Void, any Error>!
            var disposable: Disposable!

            beforeEach {
                task = Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
                disposable = task.asDisposable
            }

            it("starts off not cancelled") {
                expect(task.isCancelled).to(beFalse())
            }

            it("disposable cancels the task that owns it") {
                disposable.dispose()
                expect(task.isCancelled).to(beTrue())
            }
        }
    }
}
