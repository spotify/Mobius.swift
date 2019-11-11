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

public extension EffectRouter where Input: Equatable {
    func routeConstant(
        _ constant: Input,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter {
        fatalError()
    }

    func routeConstant(
        _ constant: Input,
        to fireAndForget: () -> Void
    ) -> EffectRouter {
        fatalError()
    }

    func routeConstant(
        _ constant: Input,
        to outputFunction: () -> Output
    ) -> EffectRouter {
        fatalError()
    }
}

public extension EffectRouter {
    func routePredicate(
        _ predicate: Input,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter {
        fatalError()
    }

    func routePredicate(
        _ predicate: Input,
        to fireAndForget: @escaping (Input) -> Void
    ) -> EffectRouter {
        fatalError()
    }

    func routePredicate(
        _ predicate: Input,
        to function: @escaping (Input) -> Output
    ) -> EffectRouter {
        fatalError()
    }
}

public extension EffectRouter {
    func routePayload<Payload>(
        _ extractPayload: (Input) -> Payload?,
        to handler: EffectHandler<Input, Output>
    ) -> EffectRouter {
        fatalError()
    }

    func routePayload<Payload>(
        _ extractPayload: (Input) -> Payload?,
        to fireAndForget: @escaping (Input) -> Void
    ) -> EffectRouter {
        fatalError()
    }

    func routePayload<Payload>(
        _ extractPayload: (Input) -> Payload?,
        to function: @escaping (Input) -> Output
    ) -> EffectRouter {
        fatalError()
    }
}
