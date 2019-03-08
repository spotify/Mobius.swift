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

/// The `First` structure defines the initial state of a Mobius loop.
public struct First<Model, Effect> where Effect: Hashable {
    /// The initial model object that should be used.
    public let model: Model
    /// An optional set of effects to initially dispatch.
    ///
    /// If empty, no effects will be dispatched.
    public let effects: Set<Effect>

    /// Initialize a `First` object with the given model and
    ///
    /// - Parameters:
    ///   - model: The initial model.
    ///   - effects: Any initial effects that should be dispatched.
    public init(model: Model, effects: Set<Effect> = []) {
        self.model = model
        self.effects = effects
    }
}

public extension First {
    /// A Boolean indicating whether the `First` object has any effects or not.
    var hasEffects: Bool { return !effects.isEmpty }
}
