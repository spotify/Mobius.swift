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

import Foundation

class EffectHandlingConnection<Effect, Event>: Disposable {
    private let handleEffect: (Effect, Response<Event>) -> Disposable?

    private let lock = Lock()
    // Keep track of each received effect's state.
    // When an effect has completed, it should be removed from this dictionary.
    // When disposing this effect handler, all entries must be removed.
    private var handlingEffects: [UUID: EffectHandlingState<Event>] = [:]
    private var unsafeOutput: Consumer<Event>?

    init(
        handleInput: @escaping (Effect, Response<Event>) -> Disposable?,
        output unsafeOutput: @escaping Consumer<Event>
    ) {
        self.handleEffect = handleInput
        self.unsafeOutput = unsafeOutput
    }

    func handle(_ effect: Effect) -> Bool {
        let id = UUID()
        let response = Response(onSend: self.output, onEnd: { [unowned self] in self.delete(id: id) })
        let effectHandlerState: EffectHandlingState<Event> = .unhandled(response: response)

        create(id: id, state: effectHandlerState)

        if let disposable = handleEffect(effect, response) {
            update(id: id) { state in state.withDisposable(disposable) }
            return true
        } else {
            delete(id: id)
            return false
        }
    }

    func dispose() {
        lock.synchronized {
            self.handlingEffects.forEach { (id, state) in
                if case .beingHandled(_, let disposable) = state {
                    disposable.dispose()
                }
            }
            self.handlingEffects = [:]
            self.unsafeOutput = nil
        }
    }

    private func create(id: UUID, state: EffectHandlingState<Event>) {
        lock.synchronized {
            self.handlingEffects[id] = state
        }
    }

    private func update(
        id: UUID,
        _ transform: (EffectHandlingState<Event>) -> EffectHandlingState<Event>
    ) {
        lock.synchronized {
            guard let state = self.handlingEffects[id] else {
                return
            }
            self.handlingEffects[id] = transform(state)
        }
    }

    private func delete(id: UUID) {
        lock.synchronized {
            _ = self.handlingEffects.removeValue(forKey: id)
        }
    }

    private func output(_ event: Event) {
        lock.synchronized {
            self.unsafeOutput?(event)
        }
    }
}

private enum EffectHandlingState<Event> {
    // The effect handler has been called, but the `handle` function has not yet returned
    case unhandled(response: Response<Event>)
    // The handle function has returned, but the effect is still being handled.
    case beingHandled(response: Response<Event>, disposable: Disposable)

    static func start(withResponse response: Response<Event>) -> EffectHandlingState<Event> {
        return .unhandled(response: response)
    }

    func withDisposable(_ disposable: Disposable) -> EffectHandlingState<Event> {
        switch self {
        case .unhandled(let response):
            return .beingHandled(response: response, disposable: disposable)
        case .beingHandled:
            fatalError("Implementation error. A disposable has already been set.")
        }
    }
}
