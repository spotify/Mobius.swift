// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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
