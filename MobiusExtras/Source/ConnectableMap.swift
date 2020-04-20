// Copyright (c) 2020 Spotify AB.
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
