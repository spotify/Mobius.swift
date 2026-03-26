// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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

        public func then(_ assertion: AssertFirst<Model, Effect>) {
            let first = initiate(model)
            assertion(first)
        }
    }
}
