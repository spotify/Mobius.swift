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
import XCTest

public typealias FirstPredicate<M, E: Hashable> = Predicate<First<M, E>>

/// Function to produce an `AssertFirst` function to be used with the `InitSpec`
///
/// - Parameter predicates: Nimble `Predicate` that verifies a first. Can be produced through `FirstMatchers`
/// - Returns: An `AssertFirst` function to be used with the `InitSpec`
public func assertThatFirst<M, E>(
    _ predicates: FirstPredicate<M, E>...,
    failFunction: @escaping AssertionFailure = XCTFail
) -> AssertFirst<M, E> {
    return { (result: First<M, E>) in
        predicates.forEach({ predicate in
            let predicateResult = predicate(result)
            if case let .failure(message, file, line) = predicateResult {
                failFunction(message, file, line)
            }
        })
    }
}

/// Returns a `Predicate` that matches `First` instances with a M that is equal to the supplied one.
///
/// - Parameter expected: the expected M
/// - Returns: a `Predicate` determening if a `First` contains the expected M
public func hasModel<M: Equatable, E>(
    _ expected: M,
    file: StaticString = #file,
    line: UInt = #line
) -> FirstPredicate<M, E> {
    return { (first: First<M, E>) in
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
public func hasNoEffects<M, E>(
    file: StaticString = #file,
    line: UInt = #line
) -> FirstPredicate<M, E> {
    return { (first: First<M, E>) in
        if first.hasEffects {
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
public func hasEffects<M, E: Equatable>(
    _ expected: [E],
    file: StaticString = #file,
    line: UInt = #line
) -> FirstPredicate<M, E> {
    return { (first: First<M, E>) in
        if !first.effects.isSuperset(of: expected) {
            return .failure(
                message: "Expected effects <\(first.effects)> to contain <\(expected)>",
                file: file,
                line: line
            )
        }
        return .success
    }
}
