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

func dumpDiff<T>(_ lhs: T, _ rhs: T) -> String {
    let lhsLines = dumpUnwrapped(lhs).split(separator: "\n")
    let rhsLines = dumpUnwrapped(rhs).split(separator: "\n")

    let x = diff(lhs: ArraySlice(lhsLines), rhs: ArraySlice(rhsLines))

    return x.reduce(into: "") { (string, diff) in
        diff.string.forEach { substring in
            string.append("\(diff.prefix)\(substring)\n")
        }
    }
}

private func dumpUnwrapped<T>(_ value: T) -> String {
    var valueDump: String = ""
    let mirror = Mirror(reflecting: value)

    if mirror.displayStyle == .optional, let first = mirror.children.first {
        dump(first.value, to: &valueDump)
    } else {
        dump(value, to: &valueDump)
    }

    return valueDump
}

private enum Difference {
    case insert(ArraySlice<Substring>)
    case delete(ArraySlice<Substring>)
    case same(ArraySlice<Substring>)

    var string: ArraySlice<Substring> {
        switch self {
        case .insert(let string): return string
        case .delete(let string): return string
        case .same(let string): return string
        }
    }

    var prefix: String {
        switch self {
        case .insert:
          return "+"
        case .delete:
          return "−"
        case .same:
          return "\u{2007}"
        }
    }
}

// Adopted from https://github.com/paulgb/simplediff
private func diff(lhs: ArraySlice<Substring>, rhs: ArraySlice<Substring>) -> [Difference] {
    var lhsIndexMap = [Substring: [Int]]()
    for (index, value) in zip(lhs.indices, lhs) {
        lhsIndexMap[value, default: []].append(index)
    }

    var lhsSubStart = lhs.startIndex
    var rhsSubStart = rhs.startIndex
    var subLength = 0
    var overlap = [Int: Int]()

    for (indexRhs, value) in zip(rhs.indices, rhs) {
      var innerOverlap = [Int: Int]()

      for indexLhs in lhsIndexMap[value, default: []] {
        innerOverlap[indexLhs] = (overlap[indexLhs - 1] ?? 0) + 1
        if innerOverlap[indexLhs]! > subLength {
          subLength = innerOverlap[indexLhs]!
          lhsSubStart = indexLhs - subLength + 1
          rhsSubStart = indexRhs - subLength + 1
        }
      }
      overlap = innerOverlap
    }

    var diffs = [Difference]()
    if subLength == 0 {
        if !lhs.isEmpty {
            diffs.append(.delete(lhs))
        }
        if !rhs.isEmpty {
            diffs.append(.insert(rhs))
        }
    } else {
        diffs.append(contentsOf: diff(lhs: lhs.prefix(upTo: lhsSubStart), rhs: rhs.prefix(upTo: rhsSubStart)))
        diffs.append(.same(rhs.suffix(from: rhsSubStart).prefix(subLength)))
        diffs.append(contentsOf: diff(lhs: lhs.suffix(from: lhsSubStart+subLength), rhs: rhs.suffix(from: rhsSubStart+subLength)))
    }
    return diffs
}
