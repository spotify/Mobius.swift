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

/// Types adopting the `Disposable` protocol can be disposed, cleaning up the resources referenced. The resouces can be
/// anything; ranging from a network request, task on the CPU or an observation of another resource.
///
/// - SeeAlso: `AnonymousDisposable` for a concrete anonymous implementation.
public protocol Disposable: AnyObject {
    /// Dispose of all resources associated with the `Disposable` object.
    ///
    /// The `Disposable` will no longer be valid after `dispose()` has been called, and any further calls to
    /// `dispose()` won’t have any effect.
    func dispose()
}
