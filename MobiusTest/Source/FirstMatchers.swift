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
import XCTest

public typealias FirstPredicate<Model, Effect> = Predicate<First<Model, Effect>>

/// Function to produce an `AssertFirst` function to be used with the `InitSpec`
///
/// - Parameter predicates: Nimble `Predicate` that verifies a first. Can be produced through `FirstMatchers`
/// - Returns: An `AssertFirst` function to be used with the `InitSpec`
public func assertThatFirst<Model, Effect>(
    _ predicates: FirstPredicate<Model, Effect>...,
    failFunction: @escaping AssertionFailure = XCTFail
) -> AssertFirst<Model, Effect> {
    return { (result: First<Model, Effect>) in
        predicates.forEach({ predicate in
            let predicateResult = predicate(result)
            if case .failure(let message, let file, let line) = predicateResult {
                failFunction(message, file, line)
            }
        })
    }
}

/// Returns a `Predicate` that matches `First` instances with a M that is equal to the supplied one.
///
/// - Parameter expected: the expected M
/// - Returns: a `Predicate` determening if a `First` contains the expected M
public func hasModel<Model: Equatable, Effect>(
    _ expected: Model,
    file: StaticString = #file,
    line: UInt = #line
) -> FirstPredicate<Model, Effect> {
    return { (first: First<Model, Effect>) in
        if first.model != expected {
            return .failure(
                message: "Expected model to be <\(expected)>, got <\(first.model)>",
                file: file,
                line: line
            )
        }
        return .success
    }
}

/// Returns a `Predicate` that matches `First` instances with no Es.
///
/// - Returns: a `Predicate` determening if a `First` contains no Es
public func hasNoEffects<Model, Effect>(
    file: StaticString = #file,
    line: UInt = #line
) -> FirstPredicate<Model, Effect> {
    return { (first: First<Model, Effect>) in
        if !first.effects.isEmpty {
            return .failure(
                message: "Expected no effects, got <\(first.effects)>",
                file: file,
                line: line
            )
        }
        return .success
    }
}

/// Returns a `Predicate` that matches if all the supplied Es are present in the supplied `First` in any order.
/// The `First` may have more Es than the ones included.
///
/// - Parameter Es: the Es to match (possibly empty)
/// - Returns: a `Predicate` that matches `First` instances that include all the supplied Es
public func hasEffects<Model, Effect: Equatable>(
    _ expected: [Effect],
    file: StaticString = #file,
    line: UInt = #line
) -> FirstPredicate<Model, Effect> {
    return { (first: First<Model, Effect>) in
        if !expected.allSatisfy(first.effects.contains) {
            return .failure(
                message: "Expected effects <\(first.effects)> to contain <\(expected)>",
                file: file,
                line: line
            )
        }
        return .success
    }
}
