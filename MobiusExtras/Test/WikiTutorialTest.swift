// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import MobiusExtras
import XCTest

/// Test cases that reproduce the Getting Started section of the GitHub wiki
class WikiTutorialTest: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testWikiCreatingALoop() {
        // Standin implementation of print()
        var printedValues: [String] = []
        func print(_ value: Any) {
            printedValues.append(String(describing: value))
        }

        // ---8<--- Wiki content start
        enum MyEvent {
            case up
            case down
        }

        func update(counter: Int, event: MyEvent) -> Int {
            switch event {
            case .up:
                return counter + 1
            case .down:
                return counter > 0
                    ? counter - 1
                    : counter
            }
        }

        let loop = Mobius.beginnerLoop(update: update)
            .start(from: 2)

        loop.addObserver { counter in print(counter) }

        loop.dispatchEvent(.down)    // prints "1"
        loop.dispatchEvent(.down)    // prints "0"
        loop.dispatchEvent(.down)    // prints "0"
        loop.dispatchEvent(.up)      // prints "1"
        loop.dispatchEvent(.up)      // prints "2"
        loop.dispatchEvent(.down)    // prints "1"

        loop.dispose()
        // ---8<--- Wiki content end

        XCTAssertEqual(printedValues, ["2", "1", "0", "0", "1", "2", "1"])
    }

    // swiftlint:disable:next function_body_length
    func testWikiCreatingALoop_addingEffects() {
        // Standin implementation of print()
        var printedValues: [String] = []
        func print(_ value: Any) {
            printedValues.append(String(describing: value))
        }

        // Carried over from previous example
        enum MyEvent {
            case up
            case down
        }

        // ---8<--- Wiki content start
        enum MyEffect {
            case reportErrorNegative
        }

        func update1(model: Int, event: MyEvent) -> Next<Int, MyEffect> {
            switch event {
            case .up:
                return .next(model + 1)
            case .down:
                return model > 0
                    ? .next(model - 1)
                    : .next(model)
            }
        }

        func update2(model: Int, event: MyEvent) -> Next<Int, MyEffect> {
            switch event {
            case .up:
                return .next(model + 1)
            case .down:
                return model > 0
                    ? .next(model - 1)
                    : .next(model, effects: [.reportErrorNegative])
            }
        }

        func update(model: Int, event: MyEvent) -> Next<Int, MyEffect> {
            switch event {
            case .up:
                return .next(model + 1)
            case .down:
                return model > 0
                    ? .next(model - 1)
                    : .dispatchEffects([.reportErrorNegative])
            }
        }

        func handleReportErrorNegative() {
            print("error!")
        }

        let effectHandler = EffectRouter<MyEffect, MyEvent>()
            .routeCase(MyEffect.reportErrorNegative).to(handleReportErrorNegative)
            .asConnectable

        let loop = Mobius.loop(update: update, effectHandler: effectHandler)
            .start(from: 2)

        loop.addObserver { counter in print(counter) }

        loop.dispatchEvent(.down)    // prints "1"
        loop.dispatchEvent(.down)    // prints "0"
        loop.dispatchEvent(.down)    // followed by "error!"
        loop.dispatchEvent(.up)      // prints "1"
        loop.dispatchEvent(.up)      // prints "2"
        loop.dispatchEvent(.down)    // prints "1"

        loop.dispose()
        // ---8<--- Wiki content end

        XCTAssertEqual(printedValues, ["2", "1", "0", "error!", "1", "2", "1"])
    }
}
