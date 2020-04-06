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

/// A connectable adapter which imposes asynchronous dispatch blocks around calls to `accept` and `dispose`.
///
/// Creates `Connection`s that forward invocations to `accept` and `dispose` to a connection returned by the underlying
/// connectable, first switching to the provided `acceptQueue`. In other words, the real `accept` and `dispose` methods
/// will always be executed asynchronously on the provided queue.
///
/// If the connection’s consumer is invoked between the Connectable’s `dispose` and the underlying asynchronous
/// `dispose`, the call will not be forwarded.
final class AsyncDispatchQueueConnectable<Input, Output>: Connectable {
    private let underlyingConnectable: AnyConnectable<Input, Output>
    private let acceptQueue: DispatchQueue

    private enum DisposalStatus: Equatable {
        case notDisposed
        case pendingDispose
        case disposed
    }

    init(
        _ underlyingConnectable: AnyConnectable<Input, Output>,
        acceptQueue: DispatchQueue
    ) {
        self.underlyingConnectable = underlyingConnectable
        self.acceptQueue = acceptQueue
    }

    convenience init<C: Connectable>(
        _ underlyingConnectable: C,
        acceptQueue: DispatchQueue
    ) where C.Input == Input, C.Output == Output {
        self.init(AnyConnectable(underlyingConnectable), acceptQueue: acceptQueue)
    }

    func connect(_ consumer: @escaping (Output) -> Void) -> Connection<Input> {
        let disposalStatus = Synchronized(value: DisposalStatus.notDisposed)

        let connection = underlyingConnectable.connect { value in
            // Don’t forward if we’re currently waiting to dispose the connection.
            //
            // NOTE: the underlying consumer must be called inside the critical region accessing disposalStatus, or we
            // could potentially enter the .pendingDispose state before or during the consumer call. This means that the
            // underlying consumer must not call our connection’s acceptClosure or disposeClosure, or it will deadlock.
            //
            // This is OK in our existing use case because the underlying consumer is always flipEventsToLoopQueue from
            // MobiusController’s initializer, which enters the actual Mobius loop asynchronously. If we exposed this
            // class, it would be a scary edge case.
            disposalStatus.read { status in
                guard status != .pendingDispose else { return }
                consumer(value)
            }
        }

        return Connection(
            acceptClosure: { [acceptQueue] input in
                acceptQueue.async {
                    connection.accept(input)
                }
            },
            disposeClosure: { [acceptQueue] in
                guard disposalStatus.compareAndSwap(expected: .notDisposed, with: .pendingDispose) else {
                    MobiusHooks.errorHandler("cannot dispose more than once", #file, #line)
                }

                acceptQueue.async {
                    connection.dispose()
                    disposalStatus.value = .disposed
                }
            }
        )
    }
}
