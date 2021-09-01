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

@testable import MobiusTest
import Nimble
import Quick

struct Person {
    let name: String
    let age: Int
    let children: [Person]
}

enum TestEnum: Equatable {
    case first, second(String), third(Int)
}

// swiftlint:disable type_body_length
class DebugDiffTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("DumpDiff") {
            var diff: String?

            context("with no change") {
                beforeEach {
                    diff = dumpDiff(
                        Person(name: "Joe", age: 10, children: []),
                        Person(name: "Joe", age: 10, children: [])
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                        ▿ MobiusTestTests.Person
                          - name: "Joe"
                          - age: 10
                          - children: 0 elements
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }

            context("with no change, second value as optional") {
                beforeEach {
                    diff = dumpDiff(
                        Person(name: "Joe", age: 10, children: []),
                        Optional.some(Person(name: "Joe", age: 10, children: []))
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                        ▿ MobiusTestTests.Person
                          - name: "Joe"
                          - age: 10
                          - children: 0 elements
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }

            context("with simple change") {
                beforeEach {
                    diff = dumpDiff(
                        Person(name: "Joe", age: 10, children: []),
                        Person(name: "Joe", age: 11, children: [])
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                        ▿ MobiusTestTests.Person
                          - name: "Joe"
                    −     - age: 10
                    +     - age: 11
                          - children: 0 elements
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }

            context("with first value nil") {
                beforeEach {
                    diff = dumpDiff(
                        nil,
                        Person(name: "Joe", age: 10, children: [])
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                    −   - nil
                    +   ▿ MobiusTestTests.Person
                    +     - name: "Joe"
                    +     - age: 10
                    +     - children: 0 elements
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }

            context("with all properties changed") {
                beforeEach {
                    diff = dumpDiff(
                        Person(name: "Joe", age: 10, children: []),
                        Person(name: "Mat", age: 40, children: [Person(name: "Pat", age: 8, children: [])])
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                        ▿ MobiusTestTests.Person
                    −     - name: "Joe"
                    −     - age: 10
                    −     - children: 0 elements
                    +     - name: "Mat"
                    +     - age: 40
                    +     ▿ children: 1 element
                    +       ▿ MobiusTestTests.Person
                    +         - name: "Pat"
                    +         - age: 8
                    +         - children: 0 elements
                    """

                    expect(diff).to(endWith(expectedDiff))
                }
            }

            context("with array items changed") {
                beforeEach {
                    diff = dumpDiff(
                        Person(name: "Joe", age: 40, children: [
                            Person(name: "Mat", age: 10, children: []),
                            Person(name: "Pat", age: 8, children: []),
                        ]),
                        Person(name: "Joe", age: 40, children: [
                            Person(name: "Pat", age: 8, children: []),
                            Person(name: "Mat", age: 10, children: []),
                        ])
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                        ▿ MobiusTestTests.Person
                          - name: "Joe"
                          - age: 40
                          ▿ children: 2 elements
                            ▿ MobiusTestTests.Person
                    −         - name: "Mat"
                    −         - age: 10
                    −         - children: 0 elements
                    −       ▿ MobiusTestTests.Person
                              - name: "Pat"
                              - age: 8
                              - children: 0 elements
                    +       ▿ MobiusTestTests.Person
                    +         - name: "Mat"
                    +         - age: 10
                    +         - children: 0 elements
                    """

                    expect(diff).to(endWith(expectedDiff))
                }
            }


            context("with complex change") {
                beforeEach {
                    diff = dumpDiff(
                        Person(name: "Joe", age: 10, children: []),
                        Person(name: "Mat", age: 40, children: [Person(name: "Pat", age: 8, children: [])])
                    )
                }
                it("returns correct diff output") {
                    let expectedDiff =
                    """
                        ▿ MobiusTestTests.Person
                    −     - name: "Joe"
                    −     - age: 10
                    −     - children: 0 elements
                    +     - name: "Mat"
                    +     - age: 40
                    +     ▿ children: 1 element
                    +       ▿ MobiusTestTests.Person
                    +         - name: "Pat"
                    +         - age: 8
                    +         - children: 0 elements
                    """

                    expect(diff).to(endWith(expectedDiff))
                }
            }
        }

        describe("ClosestDiff") {
            var diffOutput: [Difference]?

            func isSame(_ difference: Difference?) -> Bool {
                if case .some(Difference.same) = difference {
                    return true
                }
                return false
            }

            context("with no matching predicate") {
                var diffCandidate: Int?

                beforeEach {
                    (diffOutput, diffCandidate) = closestDiff(for: 1, in: [2], predicate: { isSame($0.first) })
                }

                it("returns no closest difference") {
                    expect(diffOutput).to(beNil())
                    expect(diffCandidate).to(beNil())
                }
            }

            context("with matching predicate") {
                var diffCandidate: [String]?

                beforeEach {
                    (diffOutput, diffCandidate) = closestDiff(for: ["g", "p", "u"], in: [["g", "c", "c"], ["g", "n", "u"]], predicate: {
                        isSame($0.first)
                    })
                }

                it("returns closest difference") {
                    let lhs = dumpUnwrapped(["g", "p", "u"]).split(separator: "\n")[...]
                    let rhs = dumpUnwrapped(["g", "n", "u"]).split(separator: "\n")[...]
                    let closestDiff = diff(lhs: lhs, rhs: rhs)
                    expect(diffOutput).to(equal(closestDiff))
                    expect(diffCandidate).to(equal(["g", "n", "u"]))
                }
            }
        }

        describe("DumpDiffFuzzy") {
            var diff: String?

            context("with matched enum cases") {
                beforeEach {
                    let expected = [TestEnum.first, TestEnum.second("a")]
                    let actual = [TestEnum.first, TestEnum.second("b")]
                    diff = dumpDiffFuzzy(expected: expected, actual: actual, withUnmatchedActual: false)
                }

                it("prints diff of the associated values") {
                    let expectedDiff =
                    """
                        - MobiusTestTests.TestEnum.first
                        ▿ MobiusTestTests.TestEnum.second
                    −     - second: "a"
                    +     - second: "b"
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }

            context("with unmatched expected effect") {
                beforeEach {
                    let expected = [TestEnum.first, TestEnum.second("a")]
                    let actual = [TestEnum.first, TestEnum.third(0)]
                    diff = dumpDiffFuzzy(expected: expected, actual: actual, withUnmatchedActual: false)
                }

                it("prints unmatched expected effect as deleted") {
                    let expectedDiff =
                    """
                        - MobiusTestTests.TestEnum.first
                    −   ▿ MobiusTestTests.TestEnum.second
                    −     - second: "a"
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }

            context("with unmatched expected effect and unmatched actual set to true") {
                beforeEach {
                    let expected = [TestEnum.first, TestEnum.second("a")]
                    let actual = [TestEnum.first, TestEnum.third(0)]
                    diff = dumpDiffFuzzy(expected: expected, actual: actual, withUnmatchedActual: true)
                }

                it("prints unmatched expected effect as deleted and unmatched actual effect as inserted") {
                    let expectedDiff =
                    """
                        - MobiusTestTests.TestEnum.first
                    −   ▿ MobiusTestTests.TestEnum.second
                    −     - second: "a"
                    +   ▿ MobiusTestTests.TestEnum.third
                    +     - third: 0
                    """

                    expect(diff).to(equal(expectedDiff))
                }
            }
        }
    }
}
