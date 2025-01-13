// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

@testable import MobiusCore
import Nimble
import Quick

class CompositeDisposableTests: QuickSpec {
    override func spec() {
        describe("CompositeDisposable") {
            var one: TestDisposable!
            var two: TestDisposable!
            var three: TestDisposable!
            var four: TestDisposable!
            var five: TestDisposable!
            var six: TestDisposable!

            var disposables: [Disposable]!

            var composite: CompositeDisposable!

            beforeEach {
                one = TestDisposable()
                two = TestDisposable()
                three = TestDisposable()
                four = TestDisposable()
                five = TestDisposable()
                six = TestDisposable()
                disposables = [one, two, three]
            }

            context("when created with disposables") {
                beforeEach {
                    composite = CompositeDisposable(disposables: disposables)
                }
                it("disposes all") {
                    composite.dispose()
                    expect(one.disposed).to(beTrue())
                    expect(two.disposed).to(beTrue())
                    expect(three.disposed).to(beTrue())
                }
            }

            context("when disposables are added after creation") {
                beforeEach {
                    composite = CompositeDisposable(disposables: disposables)
                    disposables[0] = four
                    disposables[1] = five
                    disposables[2] = six
                }
                it("doesn’t dispose last") {
                    composite.dispose()
                    expect(one.disposed).to(beTrue())
                    expect(two.disposed).to(beTrue())
                    expect(three.disposed).to(beTrue())
                    expect(four.disposed).to(beFalse())
                    expect(five.disposed).to(beFalse())
                    expect(six.disposed).to(beFalse())
                }
            }
        }
    }
}
