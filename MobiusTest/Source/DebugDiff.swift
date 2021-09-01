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

/// Diff two values by comparing their dumps by line by line.
/// - Parameters:
///   - lhs: Old value
///   - rhs: New value
/// - Returns: formatted diff string
func dumpDiff<T>(_ lhs: T, _ rhs: T) -> String {
    let lhsLines = dumpUnwrapped(lhs).lines
    let rhsLines = dumpUnwrapped(rhs).lines

    let diffList = diff(lhs: lhsLines, rhs: rhsLines)

    return diffList.diffString
}

/// Diff two collections of items by picking the most similar value from `actual` for each of the items
/// in `expected`. Matched values are diffed by comparing their dumps line by line.
///
/// “Similar” is defined as starting with at least one matching line – in the common case of enums with
/// associated types, this means the same case. “Best match” is defined as the one with the smallest number of
/// line differences.
///
/// - Parameters:
///     - expected: Values that are expected to be found in `actual`
///     - actual: Values that the `expected` values are diffed against
///     - withUnmatchedActual: Whether the unmatched values from `actual` should be included in the diff
/// - Returns: formatted diff string
func dumpDiffFuzzy<T>(expected: [T], actual: [T], withUnmatchedActual: Bool) -> String where T: Equatable {
    var actual = actual

    let diffItem = { (item: T) -> [Difference] in
        let closestResult = closestDiff(
            for: item,
            in: actual,
            predicate: { $0.first?.isSame ?? false } // Only use diff if first line (typically case name) matches
        )

        if let diffList = closestResult.0,
           let matchedCandidate = closestResult.1,
           let matchedIndex = actual.firstIndex(of: matchedCandidate) {
            actual.remove(at: matchedIndex)
            return diffList
        } else {
            return [Difference.delete(dumpUnwrapped(item).lines)]
        }
    }

    let expectedDifference = expected.flatMap(diffItem)
    let unmatchedActualDifference = withUnmatchedActual ? actual.map { Difference.insert(dumpUnwrapped($0).lines) } : []

    return (expectedDifference + unmatchedActualDifference).diffString
}

func dumpUnwrapped<T>(_ value: T) -> String {
    var valueDump: String = ""
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle == .optional, let first = mirror.children.first {
        dump(first.value, to: &valueDump)
    } else {
        dump(value, to: &valueDump)
    }

    return valueDump
}

func closestDiff<T, S: Sequence>(
    for value: T,
    in sequence: S,
    predicate: ([Difference]) -> Bool = { _ in true }
) -> ([Difference]?, T?) where S.Element == T {
    var closestDiff: [Difference]?
    var closestDistance = Int.max
    var closestCandidate: T?

    let unwrappedValue = dumpUnwrapped(value).lines

    sequence.forEach { candidate in
        let unwrappedCandidate = dumpUnwrapped(candidate).lines
        let diffList = diff(lhs: unwrappedValue, rhs: unwrappedCandidate)

        let distance = diffList.diffCount
        if distance < closestDistance && predicate(diffList) {
            closestDiff = diffList
            closestDistance = distance
            closestCandidate = candidate
        }
    }

    return (closestDiff, closestCandidate)
}

private extension String {
    var lines: ArraySlice<Substring> {
        split(separator: "\n")[...]
    }
}

private extension Array where Element == Difference {
    // Return the number of entries that are differences
    var diffCount: Int {
        reduce(0) { count, element in
            switch element {
            case .insert(let lines), .delete(let lines):
                return count + lines.count
            case .same:
                return count
            }
        }
    }

    var diffString: String {
        flatMap { diff in
            diff.string.map { "\(diff.prefix)   \($0)" }
        }
        .joined(separator: "\n")
    }
}
