// Copyright 2019-2022 Spotify AB.
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

import MobiusCore

public struct UpdateSpec<Model, Event, Effect> {
    public typealias Assert = (Result) -> Void

    private let update: Update<Model, Event, Effect>

    public init(_ update: Update<Model, Event, Effect>) {
        self.update = update
    }

    public init(_ update: @escaping (Model, Event) -> Next<Model, Effect>) {
        self.init(Update(update))
    }

    public func given(_ model: Model) -> When {
        return When(update, model)
    }

    public struct When {
        private let update: Update<Model, Event, Effect>
        private let model: Model

        init(_ update: Update<Model, Event, Effect>, _ model: Model) {
            self.update = update
            self.model = model
        }

        public func when(_ event: Event, _ moreEvents: Event...) -> Then {
            return Then(update, model, [event] + moreEvents)
        }
    }

    public struct Then {
        private let update: Update<Model, Event, Effect>
        private let model: Model
        private let events: [Event]

        init(_ update: Update<Model, Event, Effect>, _ model: Model, _ events: [Event]) {
            self.update = update
            self.model = model
            self.events = events
        }

        public func then(_ expression: Assert) {
            var lastNext: Next<Model, Effect>?
            var lastModel = model

            for event in events {
                lastNext = update.update(model: lastModel, event: event)
                lastModel = lastNext?.model ?? lastModel
            }

            // there will always be at least one event, so lastNext is guaranteed to have a value
            expression(Result(model: lastModel, lastNext: lastNext!))
        }
    }

    public struct Result {
        public let model: Model
        public let lastNext: Next<Model, Effect>
    }
}
