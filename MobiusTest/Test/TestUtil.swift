// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import MobiusTest

extension MobiusTest.PredicateResult {
    var failureMessage: String? {
        if case .failure(let message, _, _) = self {
            return message
        }
        return nil
    }

    var wasSuccessful: Bool {
        if case .success = self {
            return true
        }
        return false
    }
}
