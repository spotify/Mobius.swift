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

/// Base class for creating an action based `connectable`.
///
/// Invoking the `connection` functions will block the current thread until done.
open class ActionConnectable<Input, Output>: Connectable {
    private var innerConnectable: ClosureConnectable<Input, Output>

    /// Initialise with an action (no input, no output).
    ///
    /// - Parameter action: Called when the `connection`’s `accept` function is called.
    public init(_ action: @escaping () -> Void) {
        innerConnectable = ClosureConnectable<Input, Output>({ _ in
            action()
        })
    }

    public func connect(_ consumer: @escaping Consumer<Output>) -> Connection<Input> {
        return innerConnectable.connect(consumer)
    }
}
