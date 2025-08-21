// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

class CallbackTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {
        describe("Callbacks") {
            context("Ending a Callback") {
                var onEndCalledTimes: Int!
                var callback: EffectCallback<Int>!

                beforeEach {
                    onEndCalledTimes = 0
                    callback = EffectCallback(onSend: { _ in }, onEnd: {
                        onEndCalledTimes += 1
                    })
                }
                it("calls the supplied `onEnd` when `.end()` is called") {
                    callback.end()

                    expect(onEndCalledTimes).to(equal(1))
                }

                it("only calls `onEnd` once when `end` is called") {
                    callback.end()
                    callback.end()
                    callback.end()

                    expect(onEndCalledTimes).to(equal(1))
                }

                it("calls `onEnd` when the Callback is deinitialized") {
                    var onEndCalled = false
                    var callback: EffectCallback<Int>? = EffectCallback(onSend: { _ in }, onEnd: {
                        onEndCalled = true
                    })

                    callback = nil

                    expect(callback).to(beNil())
                    expect(onEndCalled).toEventually(beTrue())
                }
            }

            context("Sending output") {
                var output: [Int]!
                var callback: EffectCallback<Int>!

                beforeEach {
                    output = []
                    callback = EffectCallback(onSend: { output.append($0) }, onEnd: {})
                }

                it("calls `onSend` when `.send` is called with the same argument") {
                    callback.send(1)
                    expect(output).to(equal([1]))
                }

                it("stops calling `onSend` when `send`ing after `.end` has been called") {
                    callback.send(1)
                    callback.send(2)
                    expect(output).to(equal([1, 2]))

                    callback.end()

                    callback.send(3)
                    expect(output).to(equal([1, 2]))
                }

                it("stops calling `onSend` when using `end(with:)` after `.end` has been called") {
                    callback.end()
                    callback.end(with: 2)
                    expect(output).to(equal([]))
                }

                it("`end(with:)` is idempotent") {
                    callback.end(with: 1, 2, 3)
                    expect(callback.ended).to(beTrue())
                    expect(output).to(equal([1, 2, 3]))

                    callback.end(with: 1, 2, 3)
                    expect(callback.ended).to(beTrue())
                    expect(output).to(equal([1, 2, 3]))
                }

                it("sends events before ending when using `.end(with:)` with varargs") {
                    callback.end(with: 1, 2, 3)
                    expect(output).to(equal([1, 2, 3]))
                    expect(callback.ended).to(beTrue())
                }

                it("sends events before ending when using `.end(with:)` with an array") {
                    callback.end(with: [1, 2, 3])
                    expect(output).to(equal([1, 2, 3]))
                    expect(callback.ended).to(beTrue())
                }
            }
        }
    }
}
