// ___FILEHEADER___

import MobiusCore

final class ___VARIABLE_productName___EffectHandler: Connectable {
    typealias InputType = ___VARIABLE_featureName___Effect
    typealias OutputType = ___VARIABLE_featureName___Event

    private let lock = NSRecursiveLock()
    private var consumer: Consumer<___VARIABLE_featureName___Event>?

    func connect(_ consumer: @escaping (___VARIABLE_featureName___Event) -> Void) -> Connection<___VARIABLE_featureName___Effect> {

        lock.lock()
        defer { lock.unlock() }
        self.consumer = consumer

        return Connection(
            acceptClosure: self.accept,
            disposeClosure: self.dispose
        )
    }

    private func accept(_ effect: ___VARIABLE_featureName___Effect) {
        // Handle the effect
    }

    private func dispatch(event: ___VARIABLE_featureName___Event) {
        lock.lock()
        defer { lock.unlock() }
        consumer?(event)
    }

    private func dispose() {
        // Make sure that the `Connection` produced in the `connect` function is never used again
        lock.lock()
        defer { lock.unlock() }
        consumer = nil
    }
}
