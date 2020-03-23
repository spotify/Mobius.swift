// Copyright (c) 2019 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import MobiusCore
import UIKit

public extension UIViewController {
    /// Attach a `MobiusController` to this `UIViewController`.
    /// A `Connection` is returned which can be used to post events to the loop.
    /// The `MobiusController` will start when this function is called, and stop when this `UIViewController` is
    /// initialized or when the returned `Connection` is disposed.
    ///
    /// Note: You should not be calling `start`, `connectView`, `stop`, or `disconnectView` on the `MobiusController`
    /// when using this extension.
    ///
    /// - Parameter controller: The `MobiusController` that should be attached
    /// - Parameter onModelChange: A closure which is called whenever the loop's model changes.
    func useMobius<Model, Event, Effect>(
        controller: MobiusController<Model, Event, Effect>,
        modelChanged onModelChange: @escaping (Model) -> Void
    ) -> Connection<Event> {
        let holder = MobiusHolder(controller: controller, onModelChange: onModelChange)

        objc_setAssociatedObject(
            self,
            .init("Mobius-Controller-Holder-Key"),
            holder,
            .OBJC_ASSOCIATION_RETAIN
        )

        return Connection(
            acceptClosure: { [unowned holder] event in
                holder.handleEvent(event)
            },
            disposeClosure: { [unowned holder] in
                holder.dispose()
            }
        )
    }
}

private final class MobiusHolder<Model, Event, Effect> {
    private let controller: MobiusController<Model, Event, Effect>
    // swiftlint:disable weak_delegate
    private let connectableDelegate: WeakConnectableDelegate<Model>
    private let connectable: WeakConnectable<Model, Event>

    init(
        controller: MobiusController<Model, Event, Effect>,
        onModelChange: @escaping (Model) -> Void
    ) {
        self.controller = controller
        self.connectable = WeakConnectable()
        self.connectableDelegate = WeakConnectableDelegate<Model>(
            onModelChange: { model in
                onModelChange(model)
            }
        )
        self.connectable.delegate = self.connectableDelegate
        controller.connectView(connectable)
        controller.start()
    }

    func handleEvent(_ event: Event) {
        connectable.send(event)
    }

    func dispose() {
        if controller.running {
            controller.stop()
            controller.disconnectView()
        }
    }

    deinit {
        dispose()
    }
}

private final class WeakConnectable<Model, Event>: ConnectableClass<Model, Event> {
    weak var delegate: WeakConnectableDelegate<Model>?

    override func handle(_ model: Model) {
        delegate?.onModelChange(model)
    }

    override func onDispose() {
        delegate = nil
    }
}

private final class WeakConnectableDelegate<Model> {
    let onModelChange: (Model) -> Void

    init(onModelChange: @escaping (Model) -> Void) {
        self.onModelChange = onModelChange
    }
}
