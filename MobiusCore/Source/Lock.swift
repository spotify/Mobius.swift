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

struct Lock {
    private let lock = NSRecursiveLock()

    func synchronized<Result>(closure: () throws -> Result) rethrows -> Result {
        lock.lock()
        defer {
            lock.unlock()
        }

        return try closure()
    }
}

final class Synchronized<Value> {
    private let lock = DispatchQueue(label: "Mobius synchronized storage")
    private var storage: Value

    init(value: Value) {
        storage = value
    }

    var value: Value {
        get {
            return lock.sync { storage }
        }
        set(newValue) {
            lock.sync { self.storage = newValue }
        }
    }

    func mutate(with closure: (inout Value) throws -> Void) rethrows {
        try lock.sync {
            try closure(&storage)
        }
    }

    func read(in closure: (Value) throws -> Void) rethrows {
        try lock.sync {
            try closure(storage)
        }
    }
}

extension Synchronized where Value: Equatable {
    func compareAndSwap(expected: Value, with newValue: Value) -> Bool {
        var success = false
        self.mutate { value in
            if value == expected {
                value = newValue
                success = true
            }
        }
        return success
    }
}
