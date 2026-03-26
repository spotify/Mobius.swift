// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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
