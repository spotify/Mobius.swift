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

@testable import MobiusCore
import Nimble
import Quick

class AnonymousDisposableTests: QuickSpec {
    // swiftlint:disable function_body_length
    override func spec() {
        describe("AnonymousDisposable") {
            var disposable: AnonymousDisposable!
            var invocationCount: Int!

            beforeEach {
                invocationCount = 0
            }

            sharedExamples("expected AnonymousDisposable behaviour") {
                it("doesn't invoke the closure before being disposed") {
                    expect(invocationCount).to(equal(0))
                }

                it("invokes the closure when being disposed") {
                    disposable.dispose()
                    expect(invocationCount).to(equal(1))
                }

                it("only invokes the closure once") {
                    disposable.dispose()
                    disposable.dispose()
                    disposable.dispose()
                    expect(invocationCount).to(equal(1))
                }
            }

            context("when initialized with a closure") {
                beforeEach {
                    disposable = AnonymousDisposable {
                        invocationCount += 1
                    }
                }

                itBehavesLike("expected AnonymousDisposable behaviour")
            }

            context("when initialized with wrapped disposable") {
                beforeEach {
                    let wrapped = WrappedDisposable {
                        invocationCount += 1
                    }
                    disposable = AnonymousDisposable(wrapped)
                }

                itBehavesLike("expected AnonymousDisposable behaviour")
            }

            context("when initialized with doubly wrapped disposable") {
                var inner: AnonymousDisposable!

                beforeEach {
                    let wrapped = WrappedDisposable {
                        invocationCount += 1
                    }
                    inner = AnonymousDisposable(wrapped)
                    disposable = AnonymousDisposable(inner)
                }

                itBehavesLike("expected AnonymousDisposable behaviour")

                it("ensures the closure is only invoked once, even if the inner wrapper is also called") {
                    disposable.dispose()
                    disposable.dispose()
                    inner.dispose()
                    disposable.dispose()
                    expect(invocationCount).to(equal(1))
                }
            }
        }

        describe("WrappedDisposable") {
            var disposable: WrappedDisposable!
            var invocationCount: Int!

            beforeEach {
                invocationCount = 0
                disposable = WrappedDisposable {
                    invocationCount += 1
                }
            }

            // The fact that WrappedClosure doesn’t deduplicate is critical to testing that AnonymousDisposable does
            it("only invokes the closure repeatedly") {
                disposable.dispose()
                disposable.dispose()
                disposable.dispose()
                expect(invocationCount).to(equal(3))
            }
        }
    }
}

private final class WrappedDisposable: Disposable {
    let disposeClosure: () -> Void

    init(dispose: @escaping () -> Void) {
        disposeClosure = dispose
    }

    func dispose() {
        disposeClosure()
    }
}
