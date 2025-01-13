// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// A function that can receive values of some type.
public typealias Consumer<Value> = (Value) -> Void

/// A function that can transform a Consumer.
public typealias ConsumerTransformer<Value> = (@escaping Consumer<Value>) -> Consumer<Value>
