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

/// An `EffectCallback` can send output and signal completion.
///
/// Sending output is done with `.send` and signaling completion is done with `.end`. You can also end in conjunction
/// with sending output using `.end(with:)`.
///
/// - Note: Once `.end` has been called (from any thread), the closure you provide in `onSend` will no longer be called.
/// - Note: The closure you provide in `onEnd` will only be called once when `.end` is called on this object.
public final class EffectCallback<Output> {
    private let onSend: (Output) -> Void
    private let onEnd: () -> Void

    public var ended: Bool {
        return _ended.value
    }

    private let _ended = Synchronized<Bool>(value: false)

    public init(
        onSend: @escaping (Output) -> Void,
        onEnd: @escaping () -> Void
    ) {
        self.onSend = onSend
        self.onEnd = onEnd
    }

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

    public func end(with outputs: Output...) {
        end(with: outputs)
    }

    public func end(with outputs: [Output]) {
        for output in outputs {
            send(output)
        }
        end()
    }

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
