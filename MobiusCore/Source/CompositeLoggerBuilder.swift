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

public struct CompositeLoggerBuilder<T: LoopTypes> {
    private let mergedLoggers: [AnyMobiusLogger<T>]

    /// Initializes a `CompositeLoggerBuilder`
    public init() {
        self.init(loggers: [])
    }

    private init(loggers: [AnyMobiusLogger<T>]) {
        self.mergedLoggers = loggers
    }

    /// The intended way to join multiple loggers together
    ///
    /// - Parameter logger: any MobiusLogger instance
    /// - Returns: a new `CompositeEventSourceBuilder` with the logger added to it
    public func addLogger<Logger: MobiusLogger>(_ logger: Logger) -> CompositeLoggerBuilder<T> where Logger.Effect == T.Effect, Logger.Model == T.Model, Logger.Event == T.Event {
        let loggers = mergedLoggers + [AnyMobiusLogger<T>(logger)]
        return CompositeLoggerBuilder(loggers: loggers)
    }

    /// Builds a single logger that composes all loggers that have been added to the builder
    ///
    /// - Returns: A MobiusLogger that forwards all logging messages to each of the builder's input loggers. The type
    /// of this logger is an implementation detail; consumers should avoid making AnyMobiusLoggers if possible.
    public func build() -> AnyMobiusLogger<T> {
        let compositeLogger = CompositeLogger<T>(loggers: mergedLoggers)
        return AnyMobiusLogger<T>(compositeLogger)
    }
}
