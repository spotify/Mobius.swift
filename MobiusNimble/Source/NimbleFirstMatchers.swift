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

import Foundation
import MobiusCore
import MobiusTest
import Nimble

/// Function produces an `AssertFirst` function to be used with the `InitSpec`
///
/// - Parameter predicates: Nimble `Predicate` that verifies a first. Can be produced through `FirstMatchers`
/// - Returns: An `AssertFirst` function to be used with the `InitSpec`
public func assertThatFirst<Model, Effect>(_ predicates: Nimble.Predicate<First<Model, Effect>>...) -> AssertFirst<Model, Effect> {
    return { (result: First<Model, Effect>) in
        predicates.forEach({ predicate in
            expect(result).to(predicate)
        })
    }
}

let nextBeingNilNotAllowed = "have a non-nil First. Got <nil>"
let unexpectedNilParameterPredicateResult = PredicateResult(bool: false, message: .expectedTo(nextBeingNilNotAllowed))

/// Returns a `Predicate` that matches `First` instances with a model that is equal to the supplied one.
///
/// - Parameter expected: the expected model
/// - Returns: a `Predicate` determining if a `First` contains the expected model
public func haveModel<Model: Equatable, Effect>(_ expected: Model) -> Nimble.Predicate<First<Model, Effect>> {
    return Nimble.Predicate<First<Model, Effect>>.define(matcher: { actualExpression -> Nimble.PredicateResult in
        guard let first = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicateResult
        }

        let expectedDescription = String(describing: expected)
        let actualDescription = String(describing: first.model)
        return PredicateResult(bool: first.model == expected, message: .expectedCustomValueTo("be <\(expectedDescription)>", "<\(actualDescription)>"))
    })
}

/// Returns a `Predicate` that matches `First` instances with no effects.
///
/// - Returns: a `Predicate` determening if a `First` contains no effects
public func haveNoEffects<Model, Effect>() -> Nimble.Predicate<First<Model, Effect>> {
    return Nimble.Predicate<First<Model, Effect>>.define(matcher: { actualExpression -> Nimble.PredicateResult in
        guard let first = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicateResult
        }

        let actualDescription = String(describing: first.effects)
        return PredicateResult(bool: first.effects.isEmpty, message: .expectedCustomValueTo("have no effect", "<\(actualDescription)>"))
    })
}

/// Returns a `Predicate` that matches if all the supplied effects are present in the supplied `First` in any order.
/// The `First` may have more effects than the ones included.
///
/// - Parameter effects: the effects to match (possibly empty)
/// - Returns: a `Predicate` that matches `First` instances that include all the supplied effects
public func haveEffects<Model, Effect: Equatable>(_ effects: Set<Effect>) -> Nimble.Predicate<First<Model, Effect>> {
    return Nimble.Predicate<First<Model, Effect>>.define(matcher: { actualExpression -> Nimble.PredicateResult in
        guard let first = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicateResult
        }

        let expectedDescription = String(describing: effects)
        let actualDescription = String(describing: first.effects)
        return PredicateResult(bool: first.effects.isSuperset(of: effects), message: .expectedCustomValueTo("contain <\(expectedDescription)>", "<\(actualDescription)> (order doesn't matter)"))
    })
}
