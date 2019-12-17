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

/// A connectable adapter which imposes asynchronous dispatch blocks around calls in both directions.
///
/// * Consumers passed to `connect` will be executed on the provided `consumerQueue`
/// * The underlying connectable’s connections’ `acceptClosure` and `disposeClosure` will be executed on the provided
///   `acceptQueue`
final class AsyncDispatchQueueConnectable<InputType, OutputType>: Connectable {
    private let underlyingConnectable: AnyConnectable<InputType, OutputType>
    private let acceptQueue: DispatchQueue

    init(
        _ underlyingConnectable: AnyConnectable<InputType, OutputType>,
        acceptQueue: DispatchQueue
    ) {
        self.underlyingConnectable = underlyingConnectable
        self.acceptQueue = acceptQueue
    }

    convenience init<C: Connectable>(
        _ underlyingConnectable: C,
        acceptQueue: DispatchQueue
    ) where C.InputType == InputType, C.OutputType == OutputType {
        self.init(AnyConnectable(underlyingConnectable), acceptQueue: acceptQueue)
    }

    func connect(_ consumer: @escaping (OutputType) -> Void) -> Connection<InputType> {
        let connection = underlyingConnectable.connect(consumer)

        return Connection(
            acceptClosure: { [acceptQueue] input in
                acceptQueue.async {
                    connection.accept(input)
                }
            },
            disposeClosure: { [acceptQueue] in
                acceptQueue.async {
                    connection.dispose()
                }
            }
        )
    }
}
