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

/// Helper to wrap initator functions with log calls.
///
/// Also adds call stack annotation where we call into the client-provided initiator.
class LoggingInitiator<Model, Effect> {
    typealias Initiator = MobiusCore.Initiator<Model, Effect>
    typealias First = MobiusCore.First<Model, Effect>

    private let realInit: Initiator
    private let willInit: (Model) -> Void
    private let didInit: (Model, First) -> Void

    init<Logger: MobiusLogger>(_ realInit: @escaping Initiator, logger: Logger)
    where Logger.Model == Model, Logger.Effect == Effect {
        self.realInit = realInit
        willInit = logger.willInitiate
        didInit = logger.didInitiate
    }

    func initiate(_ model: Model) -> First {
        willInit(model)
        let result = invokeInitiate(model: model)
        didInit(model, result)

        return result
    }

    @inline(never)
    @_silgen_name("__MOBIUS_IS_CALLING_AN_INITIATOR_FUNCTION__")
    private func invokeInitiate(model: Model) -> First {
        return realInit(model)
    }
}

extension Update {
    /// Helper to wrap update functions with log calls.
    ///
    /// Also adds call stack annotation where we call into the client-provided update.
    @inline(never)
    @_silgen_name("__MOBIUS_IS_CALLING_AN_UPDATE_FUNCTION__")
    func logging<L: MobiusLogger>(_ logger: L) -> Update where L.Model == Model, L.Event == Event, L.Effect == Effect {
        return Update { model, event in
            logger.willUpdate(model: model, event: event)
            let effects = self.update(into: &model, event: event)
            logger.didUpdate(model: model, event: event, next: Next(model: model, effects: effects))
            return effects
        }
    }
}
