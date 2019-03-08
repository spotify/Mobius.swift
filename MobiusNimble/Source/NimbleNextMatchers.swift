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

/// Convenience function for creating assertions.
///
/// - Parameter predicates: matchers an array of `Predicate`, all of which must match
/// - Returns: an `Assert` that applies all the matchers
public func assertThatNext<T: LoopTypes>(_ predicates: Nimble.Predicate<Next<T.Model, T.Effect>>...) -> UpdateSpec<T>.Assert {
    return { (result: UpdateSpec<T>.Result) in
        predicates.forEach({ predicate in
            expect(result.lastNext).to(predicate)
        })
    }
}

let haveNonNilNext = "have a non-nil Next. Got <nil>"
let unexpectedNilParameterPredicate = Nimble.PredicateResult(bool: false, message: .expectedTo(haveNonNilNext))

/// - Returns: a `Predicate` that matches `Next` instances with no model and no effects.
public func haveNothing<Model, Effect>() -> Nimble.Predicate<Next<Model, Effect>> {
    return haveNoModel() && haveNoEffects()
}

/// - Returns: a `Predicate` that matches `Next` instances without a model.
public func haveNoModel<Model, Effect>() -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        var actualDescription = ""
        if let model = next.model {
            actualDescription = String(describing: model)
        }
        return Nimble.PredicateResult(bool: next.model == nil, message: .expectedCustomValueTo("have no model", "<\(actualDescription)>"))
    })
}

/// - Returns:  a `Predicate` that matches `Next` instances with a model.
public func haveModel<Model, Effect>() -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        return Nimble.PredicateResult(bool: next.model != nil, message: .expectedTo("not have a <nil> model"))
    })
}

/// - Parameter expected: the expected model
/// - Returns: a `Predicate` that matches `Next` instances with a model that is equal to the supplied one.
public func haveModel<Model: Equatable, Effect>(_ expected: Model) -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        guard let nextModel = next.model else {
            return Nimble.PredicateResult(bool: false, message: .expectedTo("have a model"))
        }

        let expectedDescription = String(describing: expected)
        let actualDescription = String(describing: nextModel)
        return Nimble.PredicateResult(bool: nextModel == expected, message: .expectedCustomValueTo("be <\(expectedDescription)>", "<\(actualDescription)>"))
    })
}

/// - Returns: a `Predicate` that matches `Next` instances with no effects.
public func haveNoEffects<Model, Effect>() -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        return Nimble.PredicateResult(bool: next.effects.isEmpty, message: .expectedTo("have no effects"))
    })
}

/// Constructs a matcher that matches if all the supplied effects are present in the supplied `Next`, in any order.
/// The `Next` may have more effects than the ones included.
///
/// - Parameter expected: the effects to match (possibly empty)
/// - Returns: a `Predicate` that matches `Next` instances that include all the supplied effects
public func haveEffects<Model, Effect: Hashable>(_ expected: Set<Effect>) -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        let expectedDescription = String(describing: expected)
        let actualDescription = String(describing: next.effects)
        return Nimble.PredicateResult(
            bool: next.effects.isSuperset(of: expected),
            message: .expectedCustomValueTo("contain <\(expectedDescription)>", "<\(actualDescription)> (order doesn't matter)")
        )
    })
}
