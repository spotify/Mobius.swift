// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore

public enum PredicateResult {
    case success
    case failure(message: String, file: StaticString, line: UInt)
}

public typealias Predicate<T> = (T) -> PredicateResult

public typealias AssertionFailure = (String, StaticString, UInt) -> Void
