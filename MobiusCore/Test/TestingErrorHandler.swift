import Foundation
import MobiusCore
import MobiusThrowableAssertion
import Nimble
import Quick

/// Nimble predicate which passes if the expression invokes `MobiusHooks.effectHandler`.
///
/// The effect handler is overridden before each test in a QuickConfiguration object. If the test has its own override,
/// for example in `beforeEach`, that will take precedence and this predicate won’t work.
///
/// - Parameter capture: An optional block which is invoked with the message, file and line of the error invocation.
public func raiseError<Out>(capture: ((String, String, UInt) -> Void)? = nil) -> Predicate<Out> {
    // This is a simplified version of Nimble’s throwAssertion() that piggybacks on Objective-C exceptions.
    return Predicate { actualExpression in
        let message = ExpectationMessage.expectedTo("throw an assertion")

        var thrownError: Error?
        let assertion = MobiusThrowableAssertion.catch {
            do {
                _ = try actualExpression.evaluate()
            } catch {
                thrownError = error
            }
        }

        if let assertion = assertion, let capture = capture {
            capture(assertion.message, assertion.file, assertion.line)
        }

        if let error = thrownError {
            return PredicateResult(
                bool: false,
                message: message.appended(message: "; threw error instead <\(error)>")
            )
        }

        return PredicateResult(bool: assertion != nil, message: message)
    }
}

private class ErrorHandlerConfiguration: QuickConfiguration {
    override class func configure(_ configuration: Configuration) {
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
