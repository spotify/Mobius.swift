// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The `First` structure defines the initial state of a Mobius loop.
public struct First<Model, Effect> {
    /// The initial model object that should be used.
    public let model: Model

    /// An optional set of effects to initially dispatch.
    ///
    /// If empty, no effects will be dispatched.
    public let effects: [Effect]

    /// Create a `First` with the given model and effects.
    ///
    /// - Parameters:
    ///   - model: The initial model.
    ///   - effects: Any initial effects that should be dispatched.
    public init(model: Model, effects: [Effect] = []) {
        self.model = model
        self.effects = effects
    }
}
