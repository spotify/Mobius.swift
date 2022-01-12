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

import Darwin

public extension EffectRouter {
    func routeCase<EffectParameters>(
        _ enumCase: @escaping (EffectParameters) -> Effect
    ) -> _PartialEffectRouter<Effect, EffectParameters, Event> {
        let casePath = CasePath(embed: enumCase)
        return routeEffects(withParameters: { effect in
            casePath.extract(from: effect)
        })
    }
}

public extension EffectRouter where Effect: Equatable {
    func routeCase(
        _ enumCase: Effect
    ) -> _PartialEffectRouter<Effect, Void, Event> {
        return routeEffects(withParameters: { effect in
            if enumCase == effect {
                return ()
            } else {
                return nil
            }
        })
    }
}
