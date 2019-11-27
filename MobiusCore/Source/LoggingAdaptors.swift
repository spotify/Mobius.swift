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
    private let realInit: Initiator<Model, Effect>
    private let willInit: (Model) -> Void
    private let didInit: (Model, First<Model, Effect>) -> Void

    init<L: MobiusLogger>(_ realInit: @escaping Initiator<Model, Effect>, _ logger: L) where L.Model == Model, L.Effect == Effect {
        self.realInit = realInit
        willInit = logger.willInitiate
        didInit = logger.didInitiate
    }

    func initiate(_ model: Model) -> First<Model, Effect> {
        willInit(model)
        let result = invokeInitiate(model: model)
        didInit(model, result)

        return result
    }

    @inline(never)
    @_silgen_name("__MOBIUS_IS_CALLING_AN_INITIATOR_FUNCTION__")
    private func invokeInitiate(model: Model) -> First<Model, Effect> {
        return realInit(model)
    }
}

/// Helper to wrap update functions with log calls.
///
/// Also adds call stack annotation where we call into the client-provided update.
class LoggingUpdate<Model, Event, Effect> {
    private let realUpdate: Update<Model, Event, Effect>
    private let willUpdate: (Model, Event) -> Void
    private let didUpdate: (Model, Event, Next<Model, Effect>) -> Void

    init<L: MobiusLogger>(_ realUpdate: @escaping Update<Model, Event, Effect>, _ logger: L) where L.Model == Model, L.Event == Event, L.Effect == Effect {
        self.realUpdate = realUpdate
        willUpdate = logger.willUpdate
        didUpdate = logger.didUpdate
    }

    func update(_ model: Model, _ event: Event) -> Next<Model, Effect> {
        willUpdate(model, event)
        let result = invokeUpdate(model: model, event: event)
        didUpdate(model, event, result)

        return result
    }

    @inline(never)
    @_silgen_name("__MOBIUS_IS_CALLING_AN_UPDATE_FUNCTION__")
    private func invokeUpdate(model: Model, event: Event) -> Next<Model, Effect> {
        return realUpdate(model, event)
    }
}
