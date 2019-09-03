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

/// A `CompositeLogger` gathers the provided loggers together and builds a single logger that
/// forwards all logging messages to each logger
public class CompositeLogger<T: LoopTypes>: MobiusLogger {
    public typealias Model = T.Model
    public typealias Event = T.Event
    public typealias Effect = T.Effect

    private let loggers: [AnyMobiusLogger<T>]

    public init(loggers: [AnyMobiusLogger<T>]) {
        self.loggers = loggers
    }

    public func willInitiate(model: T.Model) {
        loggers.forEach { $0.willInitiate(model: model) }
    }

    public func didInitiate(model: T.Model, first: First<T.Model, T.Effect>) {
        loggers.reversed().forEach { $0.didInitiate(model: model, first: first) }
    }

    public func willUpdate(model: T.Model, event: T.Event) {
        loggers.forEach { $0.willUpdate(model: model, event: event) }
    }

    public func didUpdate(model: T.Model, event: T.Event, next: Next<T.Model, T.Effect>) {
        loggers.reversed().forEach { $0.didUpdate(model: model, event: event, next: next) }
    }
}
