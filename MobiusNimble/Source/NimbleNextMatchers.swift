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

import Foundation
import MobiusCore
import MobiusTest
import Nimble

/// Convenience function for creating assertions.
///
/// - Parameter predicates: matchers an array of `Predicate`, all of which must match
/// - Returns: an `Assert` that applies all the matchers
public func assertThatNext<Model, Event, Effect>(
    _ predicates: Nimble.Predicate<Next<Model, Effect>>...
) -> UpdateSpec<Model, Event, Effect>.Assert {
    return { (result: UpdateSpec.Result) in
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
        return Nimble.PredicateResult(
            bool: next.model == nil,
            message: .expectedCustomValueTo("have no model", actual: "<\(actualDescription)>")
        )
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
        return Nimble.PredicateResult(
            bool: nextModel == expected,
            message: .expectedCustomValueTo("be <\(expectedDescription)>", actual: "<\(actualDescription)>")
        )
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
public func haveEffects<Model, Effect: Equatable>(_ expected: [Effect]) -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        let expectedDescription = String(describing: expected)
        let actualDescription = String(describing: next.effects)
        return Nimble.PredicateResult(
            bool: expected.allSatisfy(next.effects.contains),
            message: .expectedCustomValueTo(
                "contain <\(expectedDescription)>",
                actual: "<\(actualDescription)> (order doesn't matter)"
            )
        )
    })
}

/// Constructs a matcher that matches if only the supplied effects are present in the supplied `Next`, in any order.
///
/// - Parameter expected: the effects to match (possibly empty)
/// - Returns: a `Predicate` that matches `Next` instances that include all the supplied effects
public func haveOnlyEffects<Model, Effect: Equatable>(_ expected: [Effect]) -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        var unmatchedActual = next.effects
        var unmatchedExpected = expected
        zip(next.effects, expected).forEach {
            _ = unmatchedActual.firstIndex(of: $1).map { unmatchedActual.remove(at: $0) }
            _ = unmatchedExpected.firstIndex(of: $0).map { unmatchedExpected.remove(at: $0) }
        }

        let expectedDescription = String(describing: expected)
        let actualDescription = String(describing: next.effects)
        return Nimble.PredicateResult(
            bool: unmatchedActual.isEmpty && unmatchedExpected.isEmpty,
            message: .expectedCustomValueTo(
                "contain only <\(expectedDescription)>",
                actual: "<\(actualDescription)> (order doesn't matter)"
            )
        )
    })
}

/// Constructs a matcher that matches if the supplied effects are equal to the supplied `Next`.
///
/// - Parameter expected: the effects to match (possibly empty)
/// - Returns: a `Predicate` that matches `Next` instances that include all the supplied effects
public func haveExactlyEffects<Model, Effect: Equatable>(_ expected: [Effect]) -> Nimble.Predicate<Next<Model, Effect>> {
    return Nimble.Predicate<Next<Model, Effect>>.define(matcher: { actualExpression in
        guard let next = try actualExpression.evaluate() else {
            return unexpectedNilParameterPredicate
        }

        let expectedDescription = String(describing: expected)
        let actualDescription = String(describing: next.effects)
        return Nimble.PredicateResult(
            bool: expected == next.effects,
            message: .expectedCustomValueTo(
                "equal <\(expectedDescription)>",
                actual: "<\(actualDescription)>"
            )
        )
    })
}
