// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore

public extension Connectable {
    /// Transform the output type of this `Connectable` by applying the `transform` function to each output.
    ///
    /// - Parameter transform: The function which should be used to transform the output of this `Connectable`
    /// - Returns: A `Connectable` which applies `transform` to each output value.
    func map<NewOutput>(_ transform: @escaping (Output) -> NewOutput) -> AnyConnectable<Input, NewOutput> {
        return AnyConnectable { dispatch in
            return self.connect { output in
                let newOutput = transform(output)
                dispatch(newOutput)
            }
        }
    }
}
