// ___FILEHEADER___

import MobiusCore

final class ___VARIABLE_productName___EventSource: EventSource, Disposable {
    typealias Event = ___VARIABLE_featureName___Event

    private var consumer: Consumer<___VARIABLE_featureName___Event>?
    private let lock = NSRecursiveLock()

    func subscribe(consumer: @escaping (___VARIABLE_featureName___Event) -> Void) -> Disposable {
        lock.lock()
        defer { lock.unlock() }
        self.consumer = consumer

        return self
    }

    func dispose() {
        lock.lock()
        defer { lock.unlock() }
        consumer = nil
    }

    private func dispatch(event: ___VARIABLE_featureName___Event) {
        lock.lock()
        defer { lock.unlock() }
        consumer?(event)
    }
}
