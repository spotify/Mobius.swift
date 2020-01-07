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

public protocol EffectHandler {
    associatedtype Effect
    associatedtype Event

    /// Handle an `Effect`.
    /// To output events, call `response.send`
    /// When you are done handling `input`, be sure to call `response.end()` to prevent memory leaks.
    ///
    /// Return a `Disposable` which tears down any resources that is being used by this effect handler.
    func handle(
        _ input: Effect,
        _ response: Response<Event>
    )  -> Disposable
}

public class Response<T> {
    public let send: (T) -> Void
    public let end: () -> Void

    public init(
        onSend: @escaping (T) -> Void,
        onEnd: @escaping () -> Void
    ) {
        self.send = onSend
        self.end = onEnd
    }
}

public struct AnyEffectHandler<Effect, Event>: EffectHandler {
    private let handler: (Effect, Response<Event>) -> Disposable

    public init(
        handle: @escaping (Effect, Response<Event>) -> Disposable
    ) {
        self.handler = handle
    }

    public func handle(_ input: Effect, _ response: Response<Event>) -> Disposable {
        return self.handler(input, response)
    }
}
