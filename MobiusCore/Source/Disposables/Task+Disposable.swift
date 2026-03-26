// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

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
