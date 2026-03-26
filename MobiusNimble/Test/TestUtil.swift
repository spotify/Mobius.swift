// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import XCTest

// The assertions in these tests are using XCTest assertions since the assertion handler for Nimble
// is replaced in order to be inspected
extension AssertionRecorder {
    var last: AssertionRecord {
        return assertions.last!
    }

    var lastMessage: String {
        return last.message.stringValue
    }

    // The assertions in these tests are using XCTest assertions since the assertion handler for Nimble
    // is replaced in order to be inspected
    #if swift(>=5.3)
    func assertExpectationSucceeded(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(last.success, "Expected expectation to succeed - it failed", file: file, line: line)
    }

    func assertExpectationFailed(file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(last.success, "Expected expectation to fail - it succeeded", file: file, line: line)
    }

    func assertLastErrorMessageHasSuffix(_ suffix: String, file: StaticString = #filePath, line: UInt = #line) {
        let errorDescription = "Error message doesn't match: Expected message <\(lastMessage)> to have suffix <\(suffix)>"
        XCTAssert(lastMessage.hasSuffix(suffix), errorDescription, file: file, line: line)
    }

    func assertLastErrorMessageContains(_ string: String, file: StaticString = #filePath, line: UInt = #line) {
        let errorDescription = "Error message doesn't match: Expected message <\(lastMessage)> to contain <\(string)>"
        XCTAssert(lastMessage.contains(string), errorDescription, file: file, line: line)
    }
    #else
    func assertExpectationSucceeded(file: StaticString = #file, line: UInt = #line) {
        XCTAssertTrue(last.success, "Expected expectation to succeed - it failed", file: file, line: line)
    }

    func assertExpectationFailed(file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(last.success, "Expected expectation to fail - it succeeded", file: file, line: line)
    }

    func assertLastErrorMessageHasSuffix(_ suffix: String, file: StaticString = #file, line: UInt = #line) {
        let errorDescription = "Error message doesn't match: Expected message <\(lastMessage)> to have suffix <\(suffix)>"
        XCTAssert(lastMessage.hasSuffix(suffix), errorDescription, file: file, line: line)
    }

    func assertLastErrorMessageContains(_ string: String, file: StaticString = #file, line: UInt = #line) {
        let errorDescription = "Error message doesn't match: Expected message <\(lastMessage)> to contain <\(string)>"
        XCTAssert(lastMessage.contains(string), errorDescription, file: file, line: line)
    }
    #endif
}
