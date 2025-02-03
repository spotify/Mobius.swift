// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

class NextTests: QuickSpec {
    private enum Effect {
        case send
        case refresh
    }

    private struct UnexpectedCase: Error {}

    // swiftlint:disable function_body_length
    override func spec() {
        describe("Next") {
            var sut: Next<String, Effect>!

            describe("init(model:effects:)") {
                context("when given a model and no effects") {
                    beforeEach {
                        sut = Next.next("foo", effects: [])
                    }

                    it("should set the model property") {
                        expect(sut.model).to(equal("foo"))
                    }

                    it("should set the effects to an empty set") {
                        expect(sut.effects).to(beEmpty())
                    }
                }

                context("when given a set of effect and no model") {
                    beforeEach {
                        sut = Next.dispatchEffects([.send, .refresh])
                    }

                    it("should set the model property to nil") {
                        expect(sut.model).to(beNil())
                    }

                    it("should set the effects to the given set") {
                        expect(sut.effects).to(contain([Effect.send, Effect.refresh]))
                    }
                }

                context("when given a model and effects") {
                    beforeEach {
                        sut = Next.next("bar", effects: [.send])
                    }

                    it("should set the model property") {
                        expect(sut.model).to(equal("bar"))
                    }

                    it("should set the effects to the given set") {
                        expect(sut.effects).to(contain([Effect.send]))
                    }
                }

                context("when given no model and no effects") {
                    beforeEach {
                        sut = Next.dispatchEffects([])
                    }

                    it("should set the model property to nil") {
                        expect(sut.model).to(beNil())
                    }

                    it("should set the effects to an empty set") {
                        expect(sut.effects).to(beEmpty())
                    }
                }
            }

            describe("creation methods") {
                describe("next(_:effects:)") {
                    it("should use an empty set as the default for effects") {
                        expect(Next<String, Effect>.next("foo").effects).to(beEmpty())
                    }

                    it("should set the model and effects properties") {
                        expect(Next<String, Effect>.next("foo", effects: [.refresh]).model).to(equal("foo"))
                        expect(Next<String, Effect>.next("foo", effects: [.refresh]).effects).to(contain(.refresh))
                    }
                }

                describe("set variant of dispatch(_:)") {
                    it("should set the model to nil") {
                        expect(Next<String, Effect>.dispatchEffects([.refresh]).model).to(beNil())
                    }

                    it("should set the model and effects properties") {
                        expect(Next<String, Effect>.dispatchEffects([.refresh]).effects).to(contain(.refresh))
                    }
                }

                describe("noChange") {
                    it("should not have a model") {
                        expect(Next<Int, Never>.noChange.model).to(beNil())
                    }

                    it("should not have any effects") {
                        expect(Next<Int, Effect>.noChange.effects).to(beEmpty())
                    }
                }
            }

            describe("Equatable") {
                context("when the model type is equatable") {
                    let model1 = "some text"
                    let model2 = "some other text"
                    let effect1 = "some event"
                    let effect2 = "different event from before"

                    it("should return true if model and effects are equal") {
                        let lhs = Next.next(model1, effects: [effect1])
                        let rhs = Next.next(model1, effects: [effect1])

                        expect(lhs == rhs).to(beTrue())
                    }

                    it("should return false if model are not equal but effects are") {
                        let lhs = Next.next(model1, effects: [effect1])
                        let rhs = Next.next(model2, effects: [effect1])

                        expect(lhs == rhs).to(beFalse())
                    }

                    it("should return false if model are equal but effects aren't") {
                        let lhs = Next.next(model1, effects: [effect1])
                        let rhs = Next.next(model1, effects: [effect2])

                        expect(lhs == rhs).to(beFalse())
                    }

                    it("should return false if neither model nor effects are equal") {
                        let lhs = Next.next(model1, effects: [effect1])
                        let rhs = Next.next(model2, effects: [effect2])

                        expect(lhs == rhs).to(beFalse())
                    }
                }
            }

            describe("debug description") {
                context("when containing a model") {
                    it("should produce the appropriate description") {
                        let next = Next<Int, Int>.next(3, effects: [1])
                        let description = String(describing: next)
                        expect(description).to(equal("(3, [1])"))
                    }
                }

                context("when no model") {
                    it("should produce the appropriate description") {
                        let next = Next<Int, Int>.dispatchEffects([1])
                        let description = String(describing: next)
                        expect(description).to(equal("(nil, [1])"))
                    }
                }
            }
        }
    }

    // swiftlint:enable function_body_length
}
