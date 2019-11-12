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

final class AsyncDispatchQueueConnectable<InputType, OutputType>: Connectable {
    private let underlyingConnectable: AnyConnectable<InputType, OutputType>
    private let acceptQueue: DispatchQueue
    private let replyQueue: DispatchQueue

    init(
        _ underlyingConnectable: AnyConnectable<InputType, OutputType>,
        acceptQueue: DispatchQueue,
        replyQueue: DispatchQueue
    ) {
        self.underlyingConnectable = underlyingConnectable
        self.acceptQueue = acceptQueue
        self.replyQueue = replyQueue
    }

    convenience init<C: Connectable>(
        _ underlyingConnectable: C,
        acceptQueue: DispatchQueue,
        replyQueue: DispatchQueue
    ) where C.InputType == InputType, C.OutputType == OutputType {
        self.init(AnyConnectable(underlyingConnectable), acceptQueue: acceptQueue, replyQueue: replyQueue)
    }

    func connect(_ consumer: @escaping (OutputType) -> Void) -> Connection<InputType> {
        let connection = underlyingConnectable.connect { [replyQueue] output in
            replyQueue.async {
                consumer(output)
            }
        }

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
