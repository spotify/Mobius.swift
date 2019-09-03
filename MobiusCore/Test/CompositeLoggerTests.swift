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

@testable import MobiusCore
import Nimble
import Quick

class CompositeLoggerTests: QuickSpec {
    override func spec() {
        describe("CompositeLogger") {
            var loggerA: TestMobiusLogger!
            var loggerB: TestMobiusLogger!
            var loggerC: TestMobiusLogger!
            var loggers: [AnyMobiusLogger<AllStrings>] = []
            var compositeLogger: CompositeLogger<AllStrings>!
            var loggingInitiator: LoggingInitiator<AllStrings>!
            var loggingUpdate: LoggingUpdate<AllStrings>!

            beforeEach {
                loggerA = TestMobiusLogger()
                loggerB = TestMobiusLogger()
                loggerC = TestMobiusLogger()
                loggers = [loggerA, loggerB, loggerC].map { AnyMobiusLogger<AllStrings>($0) }
                compositeLogger = CompositeLogger<AllStrings>(loggers: loggers)
                loggingInitiator = LoggingInitiator({ model in First(model: model) }, compositeLogger)
                loggingUpdate = LoggingUpdate({ model, event in Next(model: model, effects: [event]) }, compositeLogger)
            }

            it("should send willInitiate and didInitiate to each logger") {
                _ = loggingInitiator.initiate("from this")
                let expectedOutput = ["willInitiate(from this)", "didInitiate(from this, First<String, String>(model: \"from this\", effects: Set([])))"]
                expect(loggerA.logMessages).to(equal(expectedOutput))
                expect(loggerB.logMessages).to(equal(expectedOutput))
                expect(loggerC.logMessages).to(equal(expectedOutput))
            }

            it("should send willUpdate and didUpdate to each logger") {
                _ = loggingUpdate.update("from this", "ee")
                let expectedOutput = ["willUpdate(from this, ee)", "didUpdate(from this, ee, (\"from this\", [\"ee\"]))"]
                expect(loggerA.logMessages).to(equal(expectedOutput))
                expect(loggerB.logMessages).to(equal(expectedOutput))
                expect(loggerC.logMessages).to(equal(expectedOutput))
            }
        }
    }
}
