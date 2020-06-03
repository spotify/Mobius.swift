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

    let diffList = diff(lhs: ArraySlice(lhsLines), rhs: ArraySlice(rhsLines))

    return diffList.reduce(into: "") { string, diff in
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
