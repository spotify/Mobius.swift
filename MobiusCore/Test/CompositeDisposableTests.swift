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

class CompositeDisposableTests: QuickSpec {
    override func spec() {
        describe("CompositeDisposable") {
            var one: TestDisposable!
            var two: TestDisposable!
            var three: TestDisposable!
            var four: TestDisposable!
            var five: TestDisposable!
            var six: TestDisposable!

            var disposables: [Disposable]!

            var composite: CompositeDisposable!

            beforeEach {
                one = TestDisposable()
                two = TestDisposable()
                three = TestDisposable()
                four = TestDisposable()
                five = TestDisposable()
                six = TestDisposable()
                disposables = [one, two, three]
            }

            context("when created with disposables") {
                beforeEach {
                    composite = CompositeDisposable(disposables: disposables)
                }
                it("disposes all") {
                    composite.dispose()
                    expect(one.disposed).to(beTrue())
                    expect(two.disposed).to(beTrue())
                    expect(three.disposed).to(beTrue())
                }
            }

            context("when disposables are added after creation") {
                beforeEach {
                    composite = CompositeDisposable(disposables: disposables)
                    disposables[0] = four
                    disposables[1] = five
                    disposables[2] = six
                }
                it("doesnt dispose last") {
                    composite.dispose()
                    expect(one.disposed).to(beTrue())
                    expect(two.disposed).to(beTrue())
                    expect(three.disposed).to(beTrue())
                    expect(four.disposed).to(beFalse())
                    expect(five.disposed).to(beFalse())
                    expect(six.disposed).to(beFalse())
                }
            }
        }
    }
}
