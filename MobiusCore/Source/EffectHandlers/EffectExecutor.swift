// Copyright 2019-2024 Spotify AB.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

final class EffectExecutor<Effect, Event>: Connectable {
    enum Operation {
        case eventEmitting((Effect, EffectCallback<Event>) -> Disposable)
        case eventReturning((Effect) -> Event?)
        case sideEffecting((Effect) -> Void)
    }

    private let operation: Operation
    private var output: Consumer<Event>?

    private let lock = Lock()

    // Keep track of each received effect's state.
    // When an effect has completed, it should be removed from this dictionary.
    // When disposing this effect handler, all entries must be removed.
    private var ongoingEffects: [Int64: EffectHandlingState<Event>] = [:]
    private var nextID = Int64(0)

    init(operation: Operation) {
        self.operation = operation
    }

    deinit {
        dispose()
    }

    func connect(_ consumer: @escaping Consumer<Event>) -> Connection<Effect> {
        return lock.synchronized {
            guard output == nil else {
                MobiusHooks.errorHandler(
                    "Connection limit exceeded: The Connectable \(type(of: self)) is already connected. " +
                    "Unable to connect more than once",
                    #file,
                    #line
                )
            }

            output = consumer
            return Connection(
                acceptClosure: handle,
                disposeClosure: dispose
            )
        }
    }

    private func handle(_ effect: Effect) {
        switch operation {
        case .eventEmitting(let handler): handleOngoing(effect, handler: handler)
        case .eventReturning(let handler): handler(effect).map { event in output?(event) }
        case .sideEffecting(let handler): handler(effect)
        }
    }

    private func dispose() {
        lock.synchronized {
            // Dispose any effects currently being handled. We also need to `end` their callbacks to remove the
            // references we are keeping to them.
            ongoingEffects.values
                .forEach {
                    $0.disposable.dispose()
                    $0.callback.end()
                }

            // Restore the state of this `Connectable` to its pre-connected state.
            ongoingEffects = [:]
            output = nil
        }
    }

    private func handleOngoing(_ effect: Effect, handler: @escaping (Effect, EffectCallback<Event>) -> Disposable) {
        let id: Int64 = lock.synchronized {
            nextID += 1
            return nextID
        }

        let callback = EffectCallback(
            // Any events produced as a result of handling the effect will be sent to this class's `output` consumer,
            // unless it has already been disposed.
            onSend: { [weak self] event in self?.output?(event) },
            // Once an effect has been handled, remove the reference to its callback and disposable.
            onEnd: { [weak self] in self?.delete(id: id) }
        )

        let disposable = handler(effect, callback)
        store(id: id, callback: callback, disposable: disposable)

        // We cannot know if `callback.end()` was called before `self.store(..)`. This check ensures that if
        // the callback was ended early, the reference to it will be deleted.
        if callback.ended {
            delete(id: id)
        }
    }

    private func store(id: Int64, callback: EffectCallback<Event>, disposable: Disposable) {
        lock.synchronized {
            ongoingEffects[id] = EffectHandlingState(callback: callback, disposable: disposable)
        }
    }

    private func delete(id: Int64) {
        lock.synchronized {
            ongoingEffects[id] = nil
        }
    }
}

private struct EffectHandlingState<Event> {
    let callback: EffectCallback<Event>
    let disposable: Disposable
}
