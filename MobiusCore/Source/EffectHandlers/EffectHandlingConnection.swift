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
    private let output: Consumer<Event>

    private let lock = Lock()

    // Keep track of each received effect's state.
    // When an effect has completed, it should be removed from this dictionary.
    // When disposing this effect handler, all entries must be removed.
    private var handlingEffects: [Int64: EffectHandlingState<Event>] = [:]
    private var nextID = Int64(0)

    init(
        handleInput: @escaping (Effect, Response<Event>) -> Disposable?,
        output: @escaping Consumer<Event>
    ) {
        self.handleEffect = handleInput
        self.output = output
    }

    func handle(_ effect: Effect) -> Bool {
        nextID += 1
        let id = nextID

        let response = Response(onSend: output, onEnd: { [weak self] in self?.delete(id: id) })

        if let disposable = handleEffect(effect, response) {
            if !response.ended {
                create(id: id, response: response, disposable: disposable)
            }
            return true
        } else {
            return false
        }
    }

    func dispose() {
        lock.synchronized {
            handlingEffects.values
                .forEach {
                    $0.disposable.dispose()
                    $0.response.end()
                }

            handlingEffects = [:]
        }
    }

    private func create(id: Int64, response: Response<Event>, disposable: Disposable) {
        lock.synchronized {
            handlingEffects[id] = EffectHandlingState(response: response, disposable: disposable)
        }
    }

    private func delete(id: Int64) {
        lock.synchronized {
            handlingEffects[id] = nil
        }
    }
}

private struct EffectHandlingState<Event> {
    let response: Response<Event>
    let disposable: Disposable
}
