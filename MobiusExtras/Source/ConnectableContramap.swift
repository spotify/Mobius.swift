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

import MobiusCore

public extension Connectable {
    /// Transform the input type of this `Connectable` by applying the `transform` function to each input.
    ///
    /// - Parameter transform: The function which should be used to transform the input to this `Connectable`
    /// - Returns: A `Connectable` which applies `transform` to each input value before handling it.
    func contramap<NewInput>(_ transform: @escaping (NewInput) -> Input) -> AnyConnectable<NewInput, Output> {
        return AnyConnectable { dispatch in
            let connection = self.connect(dispatch)

            return Connection(
                acceptClosure: { connection.accept(transform($0)) },
                disposeClosure: connection.dispose
            )
        }
    }
}
