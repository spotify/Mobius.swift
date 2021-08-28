// Copyright (c) 2008 - 2013 Paul Butler and contributors
//
// This sofware may be used under a zlib/libpng-style license:
//
// This software is provided 'as-is', without any express or implied warranty. In
// no event will the authors be held liable for any damages arising from the use
// of this software.
//
// Permission is granted to anyone to use this software for any purpose, including
// commercial applications, and to alter it and redistribute it freely, subject to
// the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not claim
// that you wrote the original software. If you use this software in a product, an
// acknowledgment in the product documentation would be appreciated but is not
// required.
//
// 2. Altered source versions must be plainly marked as such, and must not be
// misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source distribution.

enum Difference: Equatable {
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

    var isSame: Bool {
        switch self {
        case .same: return true
        default: return false
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

func diff(lhs: ArraySlice<Substring>, rhs: ArraySlice<Substring>) -> [Difference] {
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
            let innerSubLength = (overlap[indexLhs - 1] ?? 0) + 1
            innerOverlap[indexLhs] = innerSubLength
            if innerSubLength > subLength {
                subLength = innerSubLength
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
        diffs.append(contentsOf: diff(lhs: lhs.suffix(from: lhsSubStart + subLength), rhs: rhs.suffix(from: rhsSubStart + subLength)))
    }
    return diffs
}
