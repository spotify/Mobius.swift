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

/// Trivial non-concurrent work queue.
///
/// Enqueued blocks are executed in FIFO order by calling `service`. Nested calls to `service` are ignored, so that
/// the queue is only processed in the outermost invocation. This avoids surprising reentrancy in effect handlers (for
/// example, if the recursion check is removed, the effect handler in `SequencingTests` will enqueue events 2 and 3
/// multiple times).
class WorkQueue {
    typealias WorkItem = () -> Void

    private var queue = Queue<WorkItem>()
    private var servicing = false
    private var access: SequentialAccessGuard

    init(accessGuard: SequentialAccessGuard = SequentialAccessGuard()) {
        access = accessGuard
    }

    /// Submit an action to be executed.
    func enqueue(_ action: @escaping WorkItem) {
        access.guard {
            queue.enqueue(action)
        }
    }

    /// Execute all pending work, if we’re not being called recursively from an invocation of `service`.
    ///
    /// If we _are_ being invoked recursively, new work submitted via `enqueue` will be executed by the ongoing
    /// `service` call, until there is no more enqueued work.
    func service() {
        access.guard {
            guard !servicing else { return }
            servicing = true
            defer { servicing = false }

            while !queue.isEmpty {
                let action = queue.dequeue()
                action()
            }
        }
    }
}

/// Trivial queue, wrapping NSMutableArray. Note that NSMutableArray has the performance guarantees of a deque, while
/// Swift’s array doesn’t and generally behaves like an array. It will likely be very rare for a loop to have so many
/// pending work items that this matters, but there’s no great overhead to doing it this way.
private struct Queue<T> {
    private var storage: NSMutableArray = []

    mutating func enqueue(_ item: T) {
        storage.add(item)
    }

    // NOTE: will crash if queue is empty.
    mutating func dequeue() -> T {
        // swiftlint:disable:next force_cast
        let result = storage.firstObject as! T
        storage.removeObject(at: 0)
        return result
    }

    var isEmpty: Bool {
        // NSMutableArray isn’t a Collection and doesn’t implement isEmpty, but SwiftLint complains anyway
        // swiftlint:disable:next empty_count
        return storage.count == 0
    }
}
