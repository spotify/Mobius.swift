// Copyright (c) 2020 Spotify AB.
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

public typealias AssertFirst<Model, Effect> = (First<Model, Effect>) -> Void

public final class InitSpec<Model, Effect> {
    let initiate: Initiate<Model, Effect>

    public init(_ initiate: @escaping Initiate<Model, Effect>) {
        self.initiate = initiate
    }

    public func when(_ model: Model) -> Then {
        return Then(model, initiate: initiate)
    }

    public struct Then {
        let model: Model
        let initiate: Initiate<Model, Effect>

        init(_ model: Model, initiate: @escaping Initiate<Model, Effect>) {
            self.model = model
            self.initiate = initiate
        }

        // It’s unclear why this was public; the replacement isn’t.
        @available(*, deprecated, message: "use InitSpec.then instead")
        public init(_ model: Model, initiator: @escaping Initiate<Model, Effect>) {
            self.init(model, initiate: initiator)
        }

        public func then(_ assertion: AssertFirst<Model, Effect>) {
            let first = initiate(model)
            assertion(first)
        }
    }
}
