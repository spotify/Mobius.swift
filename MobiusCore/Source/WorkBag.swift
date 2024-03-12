// Copyright 2019-2024 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Like a work queue, but aggressively avoids doing things sequentially.
///
/// We don’t want to commit to any sequencing guarantees in Mobius loops. Since we’re cognizant of Hyrum’s Law, we don’t
/// want to provide _unguaranteed_ sequencing either, so this implementation currently randomizes execution order. We
/// can change this later to give any specific guarantees we want to commit to.
///
/// Submitted blocks are executed in random order by calling `service`. Nested calls to `service` are ignored, so that
/// work is only processed in the outermost invocation. This avoids surprising reentrancy in effect handlers (for
/// example, if the recursion check is removed, the effect handler in `SequencingTests` will enqueue events 2 and 3
/// multiple times).
final class WorkBag {
    typealias WorkItem = () -> Void

    private enum State {
        case notStarted
        case idle
        case servicing
    }

    private var queue = [WorkItem]()
    private var state = State.notStarted
    private var access: ConcurrentAccessDetector

    init(accessGuard: ConcurrentAccessDetector = ConcurrentAccessDetector()) {
        access = accessGuard
    }

    /// Start the workbag. Must be called once and once only in order to process events.
    func start() {
        access.guard {
            precondition(state == .notStarted)
            state = .idle
        }
        service()
    }

    /// Submit an action to be executed.
    func submit(_ action: @escaping WorkItem) {
        access.guard {
            queue.append(action)
        }
    }

    /// Execute all pending work, if we’re not being called recursively from an invocation of `service`.
    ///
    /// If we _are_ being invoked recursively, new work submitted via `submit` will be executed by the ongoing `service`
    /// call, until there is no more pending work.
    func service() {
        access.guard {
            guard state == .idle else { return }
            state = .servicing
            defer { state = .idle }

            while let action = next() {
                action()
            }
        }
    }

    private func next() -> WorkItem? {
        guard !queue.isEmpty else { return nil }
        return queue.remove(at: Int.random(in: 0..<queue.endIndex))
    }
}
