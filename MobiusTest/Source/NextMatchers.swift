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
import XCTest

public typealias NextPredicate<Model, Effect> = Predicate<Next<Model, Effect>>

/// Convenience function to produce `UpdateSpec` `Assert`
///
/// - Parameters:
///   - predicate: a list of predicates to test
///   - failFunction: a function which is called when the predicate fails. Defaults to XCTFail
/// - Returns: An `UpdateSpec` `Assert` that uses the assert to verify the result passed in to the `Assert`
public func assertThatNext<Model, Event, Effect>(
    _ predicates: NextPredicate<Model, Effect>...,
    failFunction: @escaping AssertionFailure = XCTFail
) -> UpdateSpec<Model, Event, Effect>.Assert {
    return { (result: UpdateSpec<Model, Event, Effect>.Result) in
        predicates.forEach({ predicate in
            let assertionResult = predicate(result.lastNext)
            if case .failure(let message, let file, let line) = assertionResult {
                failFunction(message, file, line)
            }
        })
    }
}

/// - Returns: a `Predicate` that matches `Next` instances with no model and no effects.
public func hasNothing<Model, Effect>(file: StaticString = #file, line: UInt = #line) -> NextPredicate<Model, Effect> {
    return { (next: Next<Model, Effect>) in
        let noModelResult = hasNoModel(file: file, line: line)(next)
        if case .success = noModelResult {
            return hasNoEffects(file: file, line: line)(next)
        }
        return noModelResult
    }
}

/// - Returns: a `Predicate` that matches `Next` instances without a model.
public func hasNoModel<Model, Effect>(file: StaticString = #file, line: UInt = #line) -> NextPredicate<Model, Effect> {
    return { (next: Next<Model, Effect>) in
        let model = next.model
        if model != nil {
            return .failure(
                message: "Expected final Next to have no model. Got: <\(String(describing: model!))>",
                file: file,
                line: line
            )
        }
        return .success
    }
}

/// - Returns:  a `Predicate` that matches `Next` instances with a model.
public func hasModel<Model, Effect>(file: StaticString = #file, line: UInt = #line) -> NextPredicate<Model, Effect> {
    return { (next: Next<Model, Effect>) in
        let model = next.model
        if model == nil {
            return .failure(
                message: "Expected final Next to have a model. Got: <nil>",
                file: file,
                line: line
            )
        }
        return .success
    }
}

/// - Parameter expected: the expected model
/// - Returns: a `Predicate` that matches `Next` instances with a model that is equal to the supplied one.
public func hasModel<Model: Equatable, Effect>(
    _ expected: Model,
    file: StaticString = #file,
    line: UInt = #line
) -> NextPredicate<Model, Effect> {
    return { (next: Next<Model, Effect>) in
        let actual = next.model
        if actual != expected {
            return .failure(
                message: "Expected final Next to have model: <\(String(describing: expected))>. " +
                    "Got: <\(String(describing: actual))>",
                file: file,
                line: line
            )
        }
        return .success
    }
}

/// - Returns: a `Predicate` that matches `Next` instances with no effects.
public func hasNoEffects<Model, Effect>(
    file: StaticString = #file,
    line: UInt = #line
) -> NextPredicate<Model, Effect> {
    return { (next: Next<Model, Effect>) in
        if !next.effects.isEmpty {
            return .failure(
                message: "Expected no effects. Got: <\(next.effects)>",
                file: file,
                line: line
            )
        }
        return .success
    }
}

/// Constructs a matcher that matches if all the supplied effects are present in the supplied `Next`, in any order.
/// The `Next` may have more effects than the ones included.
///
/// - Parameter expected: the effects to match (possibly empty)
/// - Returns: a `Predicate` that matches `Next` instances that include all the supplied effects
public func hasEffects<Model, Effect: Equatable>(
    _ expected: [Effect],
    file: StaticString = #file,
    line: UInt = #line
) -> NextPredicate<Model, Effect> {
    return { (next: Next<Model, Effect>) in
        let actual = next.effects
        if !expected.allSatisfy(actual.contains) {
            return .failure(message: "Expected <\(actual)> to contain <\(expected)>", file: file, line: line)
        }
        return .success
    }
}
