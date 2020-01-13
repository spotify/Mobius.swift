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

class EffectExecutor<Effect, Event>: Connectable {
    private let handleEffect: (Effect, Response<Event>) -> Disposable
    private var output: Consumer<Event>?

    private let lock = Lock()

    // Keep track of each received effect's state.
    // When an effect has completed, it should be removed from this dictionary.
    // When disposing this effect handler, all entries must be removed.
    private var handlingEffects: [Int64: EffectHandlingState<Event>] = [:]
    private var nextID = Int64(0)

    init(handleInput: @escaping (Effect, Response<Event>) -> Disposable) {
        self.handleEffect = handleInput
    }

    func connect(_ consumer: @escaping Consumer<Event>) -> Connection<Effect> {
        return lock.synchronized {
            guard output == nil else {
                MobiusHooks.onError("ConnectionLimitExceeded: The Connectable \(type(of: self)) is already connected. Unable to connect more than once")
                return BrokenConnection.connection()
            }

            output = consumer
            return Connection(
                acceptClosure: handle,
                disposeClosure: dispose
            )
        }
    }

    func handle(_ effect: Effect) {
        let id: Int64 = lock.synchronized {
            nextID += 1
            return nextID
        }

        let response = Response(
            // Any events produced as a result of handling the effect will be sent to this class's `output` consumer,
            // unless it has already been disposed.
            onSend: { [weak self] event in self?.output?(event) },
            // Once an effect has been handled, remove the reference to its response and disposable.
            onEnd: { [weak self] in self?.delete(id: id) }
        )

        let disposable = handleEffect(effect, response)

        store(id: id, response: response, disposable: disposable)
        if response.ended {
            delete(id: id)
        }
    }

    func dispose() {
        lock.synchronized {
            // Dispose any effects currently being handled. We also need to `end` their responses to remove the
            // references we are keeping to them.
            handlingEffects.values
                .forEach {
                    $0.disposable.dispose()
                    $0.response.end()
                }

            // Restore the state of this `Connectable` to its pre-connected state.
            handlingEffects = [:]
            output = nil
        }
    }

    private func store(id: Int64, response: Response<Event>, disposable: Disposable) {
        lock.synchronized {
            handlingEffects[id] = EffectHandlingState(response: response, disposable: disposable)
        }
    }

    private func delete(id: Int64) {
        lock.synchronized {
            handlingEffects[id] = nil
        }
    }

    deinit {
        dispose()
    }
}

private struct EffectHandlingState<Event> {
    let response: Response<Event>
    let disposable: Disposable
}
