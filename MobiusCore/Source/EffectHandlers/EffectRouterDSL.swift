// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import Foundation

public extension EffectRouter where Effect: Equatable {
    /// Add a route for effects which are equal to `constant`.
    ///
    /// - Parameter `constant`: the effect that should be handled by this route.
    func routeEffects(
        equalTo constant: Effect
    ) -> _PartialEffectRouter<Effect, Effect, Event> {
        return routeEffects(withParameters: { effect in effect == constant ? effect : nil })
    }
}

public extension _PartialEffectRouter {
    /// Route to the anonymous  `EffectHandler` defined by the `handle` closure.
    ///
    /// - Parameter handle: A closure which defines an `EffectHandler`.
    func to(
        _ handle: @escaping (EffectParameters, EffectCallback<Event>) -> Disposable
    ) -> EffectRouter<Effect, Event> {
        return to(AnyEffectHandler(handle: handle))
    }

    /// Route to a side-effecting closure.
    ///
    /// - Parameter fireAndForget: a function which given some input carries out a side effect.
    func to(
        _ fireAndForget: @escaping (EffectParameters) -> Void
    ) -> EffectRouter<Effect, Event> {
        return to { parameters, callback in
            fireAndForget(parameters)
            callback.end()
            return AnonymousDisposable {}
        }
    }

    /// Route main-isolated effects through the same queue path as `.on(queue: .main)`.
    ///
    /// This returns a dedicated builder exposing `to(...)` for `@MainActor` closures.
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func onMainActor() -> _MainActorPartialEffectRouter<Effect, EffectParameters, Event> {
        return _MainActorPartialEffectRouter(partialRouter: on(queue: .main))
    }

    /// Route to a closure which returns an optional event when given the parameters as input.
    ///
    /// - Parameter eventClosure: a function which returns an optional event given some input. No events will be
    ///   propagated if this function returns `nil`.
    func toEvent(
        _ eventClosure: @escaping (EffectParameters) -> Event?
    ) -> EffectRouter<Effect, Event> {
        return to { parameters, callback in
            if let event = eventClosure(parameters) {
                callback.send(event)
            }
            callback.end()
            return AnonymousDisposable {}
        }
    }
}

/// A `_MainActorPartialEffectRouter` represents the state between an `onMainActor` call and a `to`.
///
/// Client code should not refer to this type directly.
public struct _MainActorPartialEffectRouter<Effect, EffectParameters, Event> {
    fileprivate let partialRouter: _PartialEffectRouter<Effect, EffectParameters, Event>
}

public extension _MainActorPartialEffectRouter {
    /// Route to a `@MainActor` side-effecting closure.
    ///
    /// Dispatches through the `.on(queue: .main)` path and assumes actor isolation once scheduled on the main queue.
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func to(
        _ fireAndForget: @MainActor @Sendable @escaping (EffectParameters) -> Void
    ) -> EffectRouter<Effect, Event> {
        return partialRouter.to { parameters, callback in
            #if compiler(>=5.10)
                MainActor.assumeIsolated {
                    fireAndForget(parameters)
                }
            #else
                dispatchPrecondition(condition: .onQueue(.main))
                fireAndForget(parameters)
            #endif
            callback.end()
            return AnonymousDisposable {}
        }
    }
}

public extension _MainActorPartialEffectRouter where EffectParameters == Void {
    /// Route to a `@MainActor` side-effecting closure with no input parameters.
    ///
    /// Dispatches through the `.on(queue: .main)` path and assumes actor isolation once scheduled on the main queue.
    @available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
    func to(
        _ fireAndForget: @MainActor @Sendable @escaping () -> Void
    ) -> EffectRouter<Effect, Event> {
        return partialRouter.to { _, callback in
            #if compiler(>=5.10)
                MainActor.assumeIsolated {
                    fireAndForget()
                }
            #else
                dispatchPrecondition(condition: .onQueue(.main))
                fireAndForget()
            #endif
            callback.end()
            return AnonymousDisposable {}
        }
    }
}
