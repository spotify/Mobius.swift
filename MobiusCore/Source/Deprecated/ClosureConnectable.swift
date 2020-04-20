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

final class ClosureConnectable<Input, Output>: Connectable {
    private var output: Consumer<Output>?
    private let closure: (Input) -> Output?
    private let lock = Lock()

    init(_ outputClosure: @escaping (Input) -> Output) {
        closure = outputClosure
    }

    init(_ noOutputClosure: @escaping (Input) -> Void) {
        closure = { input in
            noOutputClosure(input)
            return nil
        }
    }

    private func dispatchInput(_ input: Input, consumer: @escaping Consumer<Output>) {
        lock.synchronized {
            if let output = self.closure(input) {
                consumer(output)
            }
        }
    }

    func connect(_ consumer: @escaping Consumer<Output>) -> Connection<Input> {
        return lock.synchronized { () -> Connection<Input> in
            self.output = consumer
            return Connection(
                acceptClosure: { input in
                    if let consumer = self.output {
                        self.dispatchInput(input, consumer: consumer)
                    }
                },
                disposeClosure: {
                    self.lock.synchronized {
                        self.output = nil
                    }
                }
            )
        }
    }
}
