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

public extension First where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    init(model: Model, effects: Set<Effect>) {
        self.model = model
        self.effects = Array(effects)
    }
}

public extension Next where Effect: Hashable {
    @available(*, deprecated, message: "use array of effects instead")
    static func next(_ model: Model, effects: Set<Effect>) -> Next<Model, Effect> {
        return .next(model, effects: Array(effects))
    }

    @available(*, deprecated, message: "use array of effects instead")
    static func dispatchEffects(_ effects: Set<Effect>) -> Next<Model, Effect> {
        return .dispatchEffects(Array(effects))
    }
}

public extension MobiusLoop {
    @available(*, deprecated, message: "use latestModel of effects instead")
    func getMostRecentModel() -> Model? {
        return latestModel
    }
}
