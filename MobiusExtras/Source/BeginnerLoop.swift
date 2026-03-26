// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore

public extension Mobius {

    /// A simplified version of `Mobius.loop` for use in tutorials.
    ///
    /// This helper simplifies setting up a loop with no effects.
    ///
    /// - Parameter update: A function taking a model and event and returning a new model.
    @inlinable
    static func beginnerLoop<Model, Event>(
        update: @escaping (Model, Event) -> Model
    ) -> Builder<Model, Event, Never> {
        let realUpdate = Update<Model, Event, Never> { model, event in
            .next(update(model, event))
        }

        let effectHandler = EffectRouter<Never, Event>()
            .asConnectable

        return loop(update: realUpdate, effectHandler: effectHandler)
    }
}
