// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import CasePaths

public extension EffectRouter {
    func routeCase<EffectParameters>(
        _ enumCase: @escaping (EffectParameters) -> Effect
    ) -> _PartialEffectRouter<Effect, EffectParameters, Event> {
        let casePath = /enumCase
        return routeEffects(withParameters: casePath.extract)
    }

    func routeCase(
        _ enumCase: Effect
    ) -> _PartialEffectRouter<Effect, Void, Event> {
        let casePath = /enumCase
        return routeEffects(withParameters: casePath.extract)
    }
}

public extension EffectRouter where Effect: Equatable {
    func routeCase(
        _ enumCase: Effect
    ) -> _PartialEffectRouter<Effect, Void, Event> {
        return routeEffects(withParameters: { effect in effect == enumCase ? () : nil })
    }
}
