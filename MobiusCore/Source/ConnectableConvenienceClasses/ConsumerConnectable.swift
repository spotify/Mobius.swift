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

/// Baseclass for creating a consumer based `connectable`. Invoking the `connection` functions
/// will block the current thread until done.
open class ConsumerConnectable<Input, Output>: Connectable {
    public typealias InputType = Input
    public typealias OutputType = Output

    private var innerConnectable: ClosureConnectable<Input, Output>

    /// Initialise with a consumer (input, no output)
    ///
    /// - Parameter consumer: Called when the `connection` `accept` function is called
    public init(_ consumer: @escaping Consumer<Input>) {
        innerConnectable = ClosureConnectable<Input, Output>(consumer)
    }

    public func connect(_ consumer: @escaping Consumer<Output>) -> Connection<Input> {
        return innerConnectable.connect(consumer)
    }
}
