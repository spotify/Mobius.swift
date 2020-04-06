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

import Foundation

/// Utility to catch invalid concurrent access to non-thread-safe code.
///
/// Like a mutex, `ConcurrentAccessDetector` guards a critical region. However, instead of blocking if two threads
/// attemt to enter the critical region at once, it crashes in debug builds. In release builds, it has no effect (and
/// also no overhead, as long as it’s only used within one module).
///
/// Copies of a `ConcurrentAccessDetector` share the same underlying mutex, and hence their critical region is the union
/// of the critical regions of all copies.
struct ConcurrentAccessDetector {
    #if DEBUG
    // This is hidden in an inner final class because we want it to be an empty struct in non-debug builds
    private final class State {
        let lock = NSRecursiveLock()
        var lastSeenLocation: Location = Location(file: "", line: 0, queue: "")
    }

    private struct Location: CustomStringConvertible {
        var file: StaticString
        var line: UInt
        var queue: String

        var description: String {
            let shortFile = String(describing: file).split(separator: "/").last ?? "<unknown>"
            return "\(shortFile): \(line) on “\(queue)”"
        }
    }

    private let state = State()

    func `guard`<T>(file: StaticString = #file, line: UInt = #line, _ block: () throws -> T) rethrows -> T {
        let location = Location(file: file, line: line, queue: currentQueueLabel())

        guard state.lock.try() else {
            preconditionFailure(
                """
                Unpermitted concurrent access.
                    Currently held by \(state.lastSeenLocation)
                    Conflicting access by \(location)

                """,
                file: file,
                line: line
            )
        }
        defer { state.lock.unlock() }

        state.lastSeenLocation = location

        return try block()
    }

    private func currentQueueLabel() -> String {
        let name = __dispatch_queue_get_label(nil)
        return String(cString: name, encoding: .utf8) ?? ""
    }
    #else
    // This currently needs to be explicitly annotated to be optimized out
    @inline(__always)
    func `guard`<T>(_ block: () throws -> T) rethrows -> T {
        return try block()
    }
    #endif
}
