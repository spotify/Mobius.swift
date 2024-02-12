@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public extension Task {

    var asDisposable: any Disposable {
        AnonymousDisposable { cancel() }
    }
}
