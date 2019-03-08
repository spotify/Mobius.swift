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

/**
 Swift currently has no native atomics support, and also doesn’t have any guarantee about atomicity for integer types.

 This is a heavyweight stopgap implementation of an atomic boolean, because the semantics of MobiusLoop are more clearly
 expressed with atomics rather than the previous implementation with locks where the invariant was unclear.
 */
struct AtomicBool {
    // All access to .storage is on this serial queue
    private let queue = DispatchQueue(label: "com.spotify.mobius.AtomicBool")
    private var storage: Bool

    init(_ value: Bool = false) {
        storage = value
    }

    var value: Bool {
        var result = false
        queue.sync {
            result = storage
        }
        return result
    }

    mutating func getAndSet(value: Bool) -> Bool {
        let newValue = value
        var oldValue = false

        queue.sync {
            oldValue = storage
            storage = newValue
        }

        return oldValue
    }
}
