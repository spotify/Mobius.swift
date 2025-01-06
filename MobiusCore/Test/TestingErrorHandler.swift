// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import MobiusCore
import MobiusThrowableAssertion
import Nimble
import Quick

/// Nimble predicate which passes if the expression invokes `MobiusHooks.errorHandler`.
///
/// The error handler is overridden before each test in a QuickConfiguration object. If the test has its own override,
/// for example in `beforeEach`, that will take precedence and this predicate won’t work.
///
/// - Parameter capture: An optional block which is invoked with the message, file and line of the error invocation.
public func raiseError<Out>(capture: ((String, String, UInt) -> Void)? = nil) -> Nimble.Predicate<Out> {
    // This is a simplified version of Nimble’s throwAssertion() that piggybacks on Objective-C exceptions.
    return Predicate { actualExpression in
        let message = ExpectationMessage.expectedTo("throw an assertion")

        // Evaluate the expression under test, and capture any assertion _or_ Swift error
        var thrownError: Error?
        let assertion = MobiusThrowableAssertion.catch {
            do {
                _ = try actualExpression.evaluate()
            } catch {
                thrownError = error
            }
        }

        // If we got a Swift error, that’s not an assertion and the test failed
        if let error = thrownError {
            return PredicateResult(
                bool: false,
                message: message.appended(message: "; threw error instead <\(error)>")
            )
        }

        // If we got an assertion and a `capture` block was passed, invoke it
        if let assertion = assertion, let capture = capture {
            capture(assertion.message, assertion.file, assertion.line)
        }

        return PredicateResult(bool: assertion != nil, message: message)
    }
}

private class ErrorHandlerConfiguration: QuickConfiguration {
    /// This is run before any Quick tests and registers `beforeEach`/`afterEach` handlers that run “outside” those
    /// set up by the tests.
    override class func configure(_ configuration: QCKConfiguration) {
        configuration.beforeEach {
            MobiusHooks.setErrorHandler { message, file, line in
                MobiusThrowableAssertion(message: message, file: String(file), line: line).throw()
            }
        }

        configuration.afterEach {
            MobiusHooks.setDefaultErrorHandler()
        }
    }
}

private extension String {
    init(_ staticString: StaticString) {
        self = staticString.withUTF8Buffer {
            String(decoding: $0, as: UTF8.self)
        }
    }
}
