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

import Foundation

/// A CompositeDisposable holds onto the provided disposables and disposes all of them once its `dispose` method is
/// called.
public final class CompositeDisposable {
    private var disposables: [Disposable]
    private let lock = DispatchQueue(label: "Mobius.CompositeDisposable")

    /// Initializes a `CompositeDisposable`.
    ///
    /// - Parameter disposables: an array of disposables.
    init(disposables: [Disposable]) {
        self.disposables = disposables
    }
}

extension CompositeDisposable: MobiusCore.Disposable {
    /// Dispose function disposes all of the internal disposables.
    public func dispose() {
        var disposables = [Disposable]()

        lock.sync {
            disposables = self.disposables
            self.disposables.removeAll()
        }

        for disposable in disposables {
            disposable.dispose()
        }
    }
}
