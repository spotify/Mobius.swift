// Copyright (c) 2019 Spotify AB.
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
/// Like a mutex, `SequentialAccessGuard` guards a critical region. However, instead of blocking if two threads attemt
/// to enter the critical region at once, it crashes in debug builds. In release builds, it has no effect (and also no
/// overhead, as long as it’s only used within one module).
///
/// Copies of a `SequentialAccessGuard` share the same underlying mutex, and hence their critical region is the union
/// of the critical regions of all copies.
struct SequentialAccessGuard {
    #if DEBUG
    private let lock = NSRecursiveLock()
    #endif

    func `guard`<T>(_ block: () throws -> T) rethrows -> T {
        #if DEBUG
        guard lock.try() else {
            preconditionFailure("Unpermitted concurrent access")
        }
        defer { lock.unlock() }
        #endif

        return try block()
    }
}
