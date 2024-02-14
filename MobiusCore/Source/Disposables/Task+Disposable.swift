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

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension Task {

    /// A disposable for use with `EffectHandler` that will cancel the task
    ///
    ///     func handle(_ parameters: Void, _ callback: EffectCallback<Event>) -> Disposable {
    ///         Task {
    ///
    ///         }
    ///        .asDisposable
    ///     }
    var asDisposable: some Disposable {
        AnonymousDisposable { cancel() }
    }
}
