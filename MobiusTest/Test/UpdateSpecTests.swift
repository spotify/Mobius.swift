// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import MobiusTest
import Nimble
import Quick

struct MyModel: Equatable {
    let buttonClicked: Bool
    let count: Int

    static func == (lhs: MyModel, rhs: MyModel) -> Bool {
        return lhs.buttonClicked == rhs.buttonClicked && lhs.count == rhs.count
    }
}

enum MyEvent {
    case didTapButton
    case didFlerbishFlerb
}

enum MyEffect {
    case triggerFroobish
}

class UpdateSpecTests: QuickSpec {
    // swiftlint:disable:next function_body_length
    override func spec() {
        let updateSpec = UpdateSpec(myUpdate)

        describe("UpdateSpec") {
            describe("single events") {
                it("should not fail for a working test case") {
                    updateSpec
                        .given(MyModel(buttonClicked: false, count: 0))
                        .when(MyEvent.didTapButton)
                        .then { result in
                            expect(result.lastNext.model?.buttonClicked).to(beTrue())
                            expect(result.lastNext.effects).to(beEmpty())
                        }
                }
                it("should report failure for a failing test case") {
                    failsWithErrorMessage("expected to be false, got <true>") {
                        updateSpec
                            .given(MyModel(buttonClicked: false, count: 0))
                            .when(MyEvent.didTapButton)
                            .then { result in
                                expect(result.lastNext.model?.buttonClicked).to(beFalse())
                            }
                    }
                }
                it("should include the input model in the result if no model change was made") {
                    updateSpec.given(MyModel(buttonClicked: false, count: 0))
                        .when(MyEvent.didFlerbishFlerb)
                        .then { result in
                            expect(result.model).to(equal(MyModel(buttonClicked: false, count: 0)))
                        }
                }
            }

            describe("multiple events") {
                it("should track the last model if the last next updates it") {
                    updateSpec.given(MyModel(buttonClicked: false, count: 0))
                        .when(MyEvent.didTapButton, MyEvent.didTapButton)
                        .then { result in
                            expect(result.model).to(equal(MyModel(buttonClicked: false, count: 2)))
                        }
                }
                it("should track the last model if the last next doesn't update it") {
                    updateSpec.given(MyModel(buttonClicked: false, count: 0))
                        .when(MyEvent.didTapButton, MyEvent.didTapButton, MyEvent.didFlerbishFlerb)
                        .then { result in
                            expect(result.model).to(equal(MyModel(buttonClicked: false, count: 2)))
                        }
                }
                it("should track the last next") {
                    updateSpec.given(MyModel(buttonClicked: false, count: 0))
                        .when(MyEvent.didTapButton, MyEvent.didTapButton)
                        .then { result in
                            expect(result.lastNext.model).to(equal(MyModel(buttonClicked: false, count: 2)))
                            expect(result.lastNext.effects).to(beEmpty())
                        }
                }
                it("should report failures if the result doesn't match") {
                    failsWithErrorMessage("expected to equal <MyModel(buttonClicked: true, count: 1)>, got <MyModel(buttonClicked: false, count: 2)>") {
                        updateSpec.given(MyModel(buttonClicked: false, count: 0))
                            .when(MyEvent.didTapButton, MyEvent.didTapButton)
                            .then { result in
                                expect(result.lastNext.model).to(equal(MyModel(buttonClicked: true, count: 1)))
                            }
                    }
                }
            }
        }
    }

    let myUpdate = Update<MyModel, MyEvent, MyEffect> { model, event in
        switch event {
        case .didTapButton:
            return Next.next(MyModel(buttonClicked: !model.buttonClicked, count: model.count + 1))
        case .didFlerbishFlerb:
            return Next.dispatchEffects([MyEffect.triggerFroobish])
        }
    }
}

// stolen from Nimble's internal test helper util.swift
private func failsWithErrorMessage(_ messages: [String], file: FileString = #file, line: UInt = #line, preferOriginalSourceLocation: Bool = false, closure: @escaping () throws -> Void) {
    var filePath = file
    var lineNumber = line

    let recorder = AssertionRecorder()
    withAssertionHandler(recorder, closure: closure)

    for msg in messages {
        var lastFailure: AssertionRecord?
        var foundFailureMessage = false

        for assertion in recorder.assertions where assertion.message.stringValue == msg && !assertion.success {
            lastFailure = assertion
            foundFailureMessage = true
            break
        }

        if foundFailureMessage {
            continue
        }

        if preferOriginalSourceLocation {
            if let failure = lastFailure {
                filePath = failure.location.file
                lineNumber = failure.location.line
            }
        }

        let message: String
        if let lastFailure = lastFailure {
            message = "Got failure message: \"\(lastFailure.message.stringValue)\", but expected \"\(msg)\""
        } else {
            let knownFailures = recorder.assertions.filter { !$0.success }.map { $0.message.stringValue }
            let knownFailuresJoined = knownFailures.joined(separator: ", ")
            message = "Expected error message (\(msg)), got (\(knownFailuresJoined))\n\nAssertions Received:\n\(recorder.assertions)"
        }

        fail(message, file: filePath, line: lineNumber)
    }
}

private func failsWithErrorMessage(_ message: String, file: FileString = #file, line: UInt = #line, preferOriginalSourceLocation: Bool = false, closure: @escaping () -> Void) {
    return failsWithErrorMessage(
        [message],
        file: file,
        line: line,
        preferOriginalSourceLocation: preferOriginalSourceLocation,
        closure: closure
    )
}
