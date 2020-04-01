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

/// An `EffectCallback` can send output and signal completion.
///
/// Sending output is done with `.send` and signaling completion is done with `.end`. You can also end in conjunction
/// with sending output using `.end(with:)`.
///
/// Note: Once either `.end` or  `.end(with:)`  have been called (from any thread), all operations on this object will be no-ops.
/// Note: The closure provided in `onEnd` will only be called once when `.end` is called on this object.
public final class EffectCallback<Output> {
    private let onSend: (Output) -> Void
    private let onEnd: () -> Void

    /// Determine if this callback has been ended.
    ///
    /// This can be called safely from any thread.
    /// Note: Once this variable is `true`, it will never be `false` again.
    public var ended: Bool {
        return _ended.value
    }

    private let _ended = Synchronized<Bool>(value: false)

    /// Create an `EffectCallback` with some behavior associated with its sending and ending mechanisms.
    ///
    /// Note: `onEnd` will only be called once on an instance of this call, regardless of how many times `end` is called.
    /// Note: `onSend` will not be called if `end` has already been called.
    /// - Parameter onSend: The closure to called when the underlying `Callback` sends output.
    /// - Parameter onEnd: The closure to be called when the underlying `Callback` is ended.
    public init(
        onSend: @escaping (Output) -> Void,
        onEnd: @escaping () -> Void
    ) {
        self.onSend = onSend
        self.onEnd = onEnd
    }

    /// Invalidate this callback.
    ///
    /// Note: any calls to `end`, `end(with:)` or `send(_:)` will be no-ops after this function has been called.
    public func end() {
        var runOnEnd = false
        _ended.mutate {
            runOnEnd = !$0
            $0 = true
        }
        if runOnEnd {
            onEnd()
        }
    }

    /// Send a number of events to the Mobius loop, then `end()` this callback.
    ///
    /// Note: After calling this function, all operations on this object will be no-ops.
    /// - Parameter outputs: The events which should be sent to the loop.
    public func end(with outputs: Output...) {
        end(with: outputs)
    }

    /// Send a number of events to the Mobius loop and `end()` this callback.
    ///
    /// Note: After calling this function, all operations on this object will be no-ops.
    /// - Parameter outputs: The events which should be sent to the loop.
    public func end(with outputs: [Output]) {
        var shouldRun = false
        _ended.mutate {
            shouldRun = !$0
            $0 = true
        }
        if shouldRun {
            for output in outputs {
                onSend(output)
            }
            onEnd()
        }
    }

    /// Send an event to the Mobius loop.
    ///
    /// Note: Calling this function after calling `.end()` or `.end(with:)` is a no-op.
    /// - Parameter output: the event that should be sent to the loop.
    public func send(_ output: Output) {
        _ended.mutate {
            if !$0 {
                onSend(output)
            }
        }
    }

    deinit {
        end()
    }
}
