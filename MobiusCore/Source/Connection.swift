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

/// Handle for a connection created by a `Connectable`.
///
/// Used for sending values to the connection and to dispose of it and all resources associated
/// with it.
public final class Connection<Value>: Disposable {
    public typealias ValueType = Value

    private let acceptClosure: (Value) -> Void
    private let disposeClosure: () -> Void

    public init(acceptClosure: @escaping (Value) -> Void, disposeClosure: @escaping () -> Void) {
        self.acceptClosure = acceptClosure
        self.disposeClosure = disposeClosure
    }

    public func accept(_ value: Value) {
        acceptClosure(value)
    }

    public func dispose() {
        disposeClosure()
    }
}
