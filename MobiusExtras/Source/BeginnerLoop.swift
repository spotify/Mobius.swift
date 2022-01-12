// Copyright 2019-2022 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
