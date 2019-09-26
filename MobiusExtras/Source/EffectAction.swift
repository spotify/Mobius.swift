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

import MobiusCore

/// A general implementation of the `ActionWithPredicate` protocol that takes a closure and triggers it when
/// the provided effect or precidate is accepted and the action runs.
public class EffectAction<Effect>: ActionWithPredicate where Effect: Equatable {
    public typealias Predicate = (Effect) -> (Bool)

    private let predicate: Predicate
    private let action: () -> Void

    /// Initializes an EffectAction with a predicate.
    ///
    /// - Parameters:
    ///   - predicate: a predicate whose accepting inputs the EffectAction accepts.
    ///   - action: a closure that gets triggered on the action run when the effect is accepted.
    public init(predicate: @escaping Predicate, action: @escaping () -> Void) {
        self.predicate = predicate
        self.action = action
    }

    /// Initializes an EffectAction with an accepted effect.
    ///
    /// - Parameters:
    ///   - acceptedEffect: en effect that the EffectAction accepts.
    ///   - action: a closure that gets triggered on the action run when the effect is accepted.
    public convenience init(_ acceptedEffect: Effect, action: @escaping () -> Void) {
        self.init(predicate: { effect in effect == acceptedEffect }, action: action)
    }

    public func canAccept(_ effect: Effect) -> Bool {
        return predicate(effect)
    }

    public func run() {
        action()
    }
}
