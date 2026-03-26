// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation
import MobiusCore

public final class SimpleLogger<Model, Event, Effect>: MobiusLogger {
    private let prefix: String
    private let consumer: Consumer<String>

    public init(tag: String = "Mobius", consumer: @escaping Consumer<String> = { print($0) }) {
        prefix = tag + ": "
        self.consumer = consumer
    }

    public func willInitiate(model: Model) {
        consumer(prefix + "Initializing loop")
    }

    public func didInitiate(model: Model, first: First<Model, Effect>) {
        consumer(prefix + "Loop initialized, starting from model: \(first.model)")

        first.effects.forEach { (effect: Effect) in
            consumer(prefix + "Effect dispatched: \(effect)")
        }
    }

    public func willUpdate(model: Model, event: Event) {
        consumer(prefix + "Event received: \(event)")
    }

    public func didUpdate(model: Model, event: Event, next: Next<Model, Effect>) {
        if let nextModel = next.model {
            consumer(prefix + "Model updated: \(nextModel)")
        }

        next.effects.forEach { (effect: Effect) in
            consumer(prefix + "Effect dispatched: \(effect)")
        }
    }
}
