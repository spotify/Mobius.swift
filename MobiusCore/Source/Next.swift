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

import Foundation

/// The `Next` type represent the result of calling an `Update` function.
///
/// Upon calling an `Update` function with an `Event` and `Model`, a `Next` object will be returned that contains the
/// new `Model` (if there is one) and any `Effect` objects that describe which side-effects should take place.
///
/// ## Creating a `Next` instance
///
/// A `Next` instance can either be created using the the initializer or the convenience factory methods. It’s
/// **recommended to use the convenience factory methods** as it helps with readability in update functions.
public struct Next<Model, Effect> {
    /// The model that should be used next.
    public let model: Model?

    /// A list of effects that should be dispatched next.
    ///
    /// Can be empty in which case no side-effects should be dispatched.
    public let effects: [Effect]
}

public extension Next {
    /// Create a `Next` that updates the model and dispatches the supplied effects.
    ///
    /// If `effects` is empty no side-effects will be dispatched.
    ///
    /// - Parameters:
    ///   - model: The model that should be used next.
    ///   - effects: The effects that should be dispatched next. Defaults to an empty array (no effects).
    /// - Returns: A `Next` that updates the model and an, optionally empty, list of effects.
    static func next(_ model: Model, effects: [Effect] = []) -> Next<Model, Effect> {
        return self.init(model: model, effects: effects)
    }

    /// Create a `Next` that doesn’t update the model but dispatches a list of effects.
    ///
    /// - Parameter effects: The effects that should be dispatched next.
    /// - Returns: A `Next` that doesn’t update the model but dispatches a list of effects.
    static func dispatchEffects(_ effects: [Effect]) -> Next<Model, Effect> {
        return self.init(model: nil, effects: effects)
    }

    /// Creates an empty `Next` that doesn’t update the model or dispatch effects.
    ///
    /// The `model` property will be `nil`, and the `effects` will be empty.
    static var noChange: Next<Model, Effect> {
        return Next(model: nil, effects: [])
    }
}

extension Next: Equatable where Model: Equatable, Effect: Equatable {
    public static func == (lhs: Next<Model, Effect>, rhs: Next<Model, Effect>) -> Bool {
        return lhs.model == rhs.model && lhs.effects == rhs.effects
    }
}

extension Next: CustomDebugStringConvertible {
    public var debugDescription: String {
        let modelDescription: String
        if let model = model {
            modelDescription = String(reflecting: model)
        } else {
            modelDescription = "nil"
        }
        return "(\(modelDescription), \(effects))"
    }
}
