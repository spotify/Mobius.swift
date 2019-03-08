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

/// Types adopting the `Copyable` protocol can be copied and changed in one operation.
public protocol Copyable {
    /// Copy the `Copyable` object and change one or more of its members.
    ///
    /// - Note: A default implementation is provided that can be used with value types. If the type adopting the
    ///         `Copyable` protocol is a reference type then it needs to provide its own implementation.
    ///
    /// - Parameter mutator: The closure that changes the copy.
    /// - Returns: The changed copy.
    func copy(with mutator: (inout Self) -> Void) -> Self
}

public extension Copyable {
    func copy(with mutator: (inout Self) -> Void) -> Self {
        var copy = self
        mutator(&copy)
        return copy
    }
}
