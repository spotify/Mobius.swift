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

public extension Connectable {
    /// Transform the output type of this `Connectable` by applying the `transform` function to each output
    /// and returning only the non-`nil` values.
    ///
    /// - Parameter transform: The function which should be used to transform the output of this `Connectable`.
    /// - Returns: A `Connectable` which applies `transform` to each output value.
    func compactMap<NewOutput>(_ transform: @escaping (Output) -> NewOutput?) -> AnyConnectable<Input, NewOutput> {
        AnyConnectable { dispatch in
            self.connect { output in
                transform(output).map(dispatch)
            }
        }
    }
}
