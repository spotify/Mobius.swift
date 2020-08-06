// Copyright (c) 2020 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

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
