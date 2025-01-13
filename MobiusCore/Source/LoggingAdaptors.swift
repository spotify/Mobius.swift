// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

typealias UpdateClosure<Model, Event, Effect> = (Model, Event) -> Next<Model, Effect>

extension MobiusLogger {
    /// Wraps an Initiate in logging calls and stack annotations
    func wrap(initiate: @escaping Initiate<Model, Effect>) -> Initiate<Model, Effect> {
        return { model in
            self.willInitiate(model: model)
            let result = invokeInitiate(initiate, model: model)
            self.didInitiate(model: model, first: result)
            return result
        }
    }

    /// Wraps an update closure in logging calls and stack annotations
    func wrap(update: @escaping UpdateClosure<Model, Event, Effect>) -> UpdateClosure<Model, Event, Effect> {
        return { model, event in
            self.willUpdate(model: model, event: event)
            let result = invokeUpdate(update, model: model, event: event)
            self.didUpdate(model: model, event: event, next: result)
            return result
        }
    }

    /// Wraps an Update in logging calls and stack annotations
    func wrap(update: Update<Model, Event, Effect>) -> Update<Model, Event, Effect> {
        return Update(wrap(update: update.updateClosure))
    }
}

/// Invoke an initiate function, leaving a hint on the stack.
///
/// To work as intended, this function must be exactly like this. `@_silgen_name` can’t be used on a closure,
/// for example.
@inline(never)
@_silgen_name("__MOBIUS_IS_CALLING_AN_INITIATOR_FUNCTION__")
private func invokeInitiate<Model, Effect>(_ initiate: Initiate<Model, Effect>, model: Model) -> First<Model, Effect> {
    return initiate(model)
}

/// Invoke an update function, leaving a hint on the stack.
///
/// To work as intended, this function must be exactly like this. `@_silgen_name` can’t be used on a closure,
/// for example.
@inline(never)
@_silgen_name("__MOBIUS_IS_CALLING_AN_UPDATE_FUNCTION__")
private func invokeUpdate<Model, Event, Effect>(
    _ update: @escaping (Model, Event) -> Next<Model, Effect>,
    model: Model,
    event: Event
) -> Next<Model, Effect> {
    return update(model, event)
}
