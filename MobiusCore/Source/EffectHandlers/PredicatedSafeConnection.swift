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

// swiftlint:disable type_name
/// `PredicatedSafeConnection` is an object which can:
/// - Receive input, which it can choose to accept or reject.
/// - Produce output.
/// - Be disposed to clean up resources.
final class PredicatedSafeConnection<Input, Output>: Disposable {
    private let handleInputWithOutput: (Input, @escaping Consumer<Output>) -> Bool
    // We cannot know if this `Consumer` is internally thread-safe. The thread-safety is therefore delegated to the
    // `output` instance function.
    private var unsafeOutput: Consumer<Output>?
    // We cannot know if this `Disposable` is internally thread-safe. The thread-safety is therefore delegated to the
    // `dispose` instance function.
    private let unsafeDispose: Disposable
    private let lock = Lock()

    init(
        handleInput: @escaping (Input, @escaping Consumer<Output>) -> Bool,
        output unsafeOutput: @escaping Consumer<Output>,
        dispose unsafeDispose: Disposable
    ) {
        self.handleInputWithOutput = handleInput
        self.unsafeOutput = unsafeOutput
        self.unsafeDispose = unsafeDispose
    }

    /// Handle input. Return true if the input could be processed.
    /// - Parameter input: the input in question
    public func handle(_ input: Input) -> Bool {
        return handleInputWithOutput(input, output)
    }

    /// Tear down the resources being consumed by this object.
    /// Note: Any attempts to send output after this function returns will result in a runtime exception.
    public func dispose() {
        self.lock.synchronized {
            unsafeDispose.dispose()
            unsafeOutput = nil
        }
    }

    private func output(event: Output) {
        self.lock.synchronized {
            guard let unsafeOutput = unsafeOutput else {
                MobiusHooks.onError("Attempted to dispatch event \(event), but the connection has already been disposed.")
                return
            }
            unsafeOutput(event)
        }
    }

    deinit {
        dispose()
    }
}
