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

/// Helper representing an entity that has a stopped state where it can be configured, and a running state where it
/// can’t, with all mutation happening on a designated dispatch queue.
///
/// In an ideal world this would just boil down to the enum `Snapshot` defined below, but Swift doesn’t provide the
/// tools to easily make it thread safe. In particular, we need to be able to query whether we’re currently running or
/// not from any queue, including the designated mutating queue.
final class AsyncStartStopStateMachine<StoppedState, RunningState> {
    // Intermediate states are required to handle the case where `running` is queried during a state transition.
    //
    // In practice, this can happen in MobiusController when an event source dispatches an event immediately when
    // subscribed to, which happens before the loop variable is assigned in start(). In this case, we enter
    // flipEventsToLoopQueue() in the .transitioningToRunning state, but the async block cannot proceed until we
    // reach the .running state (because start() is already running on the loop queue).
    private enum RawState {
        case stopped
        case transitioningToRunning
        case running
        case transitioningToStopped
    }

    enum Error: Swift.Error {
        case wrongState
    }

    private let rawState = Synchronized(value: RawState.stopped)
    private let queue: DispatchQueue

    // Invariant: only one of these optionals is meaningful at any given time. They are only read in `snapshot`.
    private var stoppedState: StoppedState?
    private var runningState: RunningState?

    enum Snapshot {
        case stopped(StoppedState)
        case running(RunningState)
    }

    init(state: StoppedState, queue: DispatchQueue) {
        stoppedState = state
        self.queue = queue
    }

    /// Test whether we’re in a running state. Ongoing transitions are considered running states.
    ///
    /// This is safe to invoke from any queue, including the loop queue.
    var running: Bool {
        switch rawState.value {
        case .stopped:
            return false
        case .transitioningToRunning, .running, .transitioningToStopped:
            return true
        }
    }

    /// Call `closure` with the current state. It will execute on the loop queue.
    func syncRead<T>(_ closure: (Snapshot) throws -> T) rethrows -> T {
        dispatchPrecondition(condition: .notOnQueue(queue))
        return try queue.sync {
            try closure(snapshot())
        }
    }

    /// Mutate the stopped state, assuming we’re currently stopped. If not, throw `Error.wrongState`.
    func mutate(by closure: (inout StoppedState) throws -> Void) throws {
        dispatchPrecondition(condition: .notOnQueue(queue))
        try queue.sync {
            switch snapshot() {
            case .running:
                throw Error.wrongState
            case .stopped(var state):
                try closure(&state)
                stoppedState = state
            }
        }
    }

    /// Transition from a stopped state to a running state, assuming we’re currently stopped. If not, fail with the
    /// provided error message.
    ///
    /// If the `transition` closure throws an error, the state remains unchanged.
    func transitionToRunning(by transition: (StoppedState) throws -> RunningState) throws {
        dispatchPrecondition(condition: .notOnQueue(queue))
        try queue.sync {
            switch snapshot() {
            case .running:
                throw Error.wrongState
            case .stopped(let stoppedState):
                rawState.value = .transitioningToRunning
                do {
                    let runningState = try transition(stoppedState)
                    become(running: runningState)
                } catch {
                    rawState.value = .stopped
                    throw error
                }
            }
        }
    }

    /// Transition from a running state to a stopped state, assuming we’re currently running. If not, fail with the
    /// provided error message.
    ///
    /// If the `transition` closure throws an error, the state remains unchanged.
    func transitionToStopped(by transition: (RunningState) throws -> StoppedState) throws {
        dispatchPrecondition(condition: .notOnQueue(queue))
        try queue.sync {
            switch snapshot() {
            case .stopped:
            throw Error.wrongState
            case .running(let runningState):
                rawState.value = .transitioningToStopped
                do {
                    let stoppedState = try transition(runningState)
                    become(stopped: stoppedState)
                } catch {
                    rawState.value = .running
                    throw error
                }
            }
        }
    }

    /// Generate a `Snapshot`  reflecting the current state.
    ///
    /// This function is the only point where we deal with the two optionals.
    private func snapshot() -> Snapshot {
        dispatchPrecondition(condition: .onQueue(queue))

        if running {
            guard let runningState = runningState else { preconditionFailure("Internal invariant broken") }
            return .running(runningState)
        } else {
            guard let stoppedState = stoppedState else { preconditionFailure("Internal invariant broken") }
            return .stopped(stoppedState)
        }
    }

    private func become(running state: RunningState) {
        dispatchPrecondition(condition: .onQueue(queue))

        self.runningState = state
        rawState.value = .running
        self.stoppedState = nil
    }

    private func become(stopped state: StoppedState) {
        dispatchPrecondition(condition: .onQueue(queue))

        self.stoppedState = state
        rawState.value = .stopped
        self.runningState = nil
    }
}
