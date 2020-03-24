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

#if canImport(UIKit)

import MobiusCore
import UIKit

public extension UIViewController {
    /// Attach a `MobiusController` to this `UIViewController`.
    /// The `connectable` you provide will be connected to the `MobiusController`.
    /// This function returns a `Disposable` which can be disposed to stop the `MobiusController`. If this disposable
    /// is never disposed, the `MobiusController` will stop when this `UIViewController` is deinitialized.
    ///
    /// Note: You should not be calling `start`, `connectView`, `stop`, or `disconnectView` on the `MobiusController`
    /// when using this extension.
    ///
    /// Note: You must keep a strong reference to the `connectable` for as long as you want the loop to exist.
    ///
    /// - Parameter controller: The `MobiusController` that should be attached
    /// - Parameter connectable: The `Connectable` which should be connected to `controller`
    func useMobius<Model, Event, Effect, Conn: Connectable>(
        controller: MobiusController<Model, Event, Effect>,
        connectable: Conn
    ) -> Disposable where Conn.Input == Model, Conn.Output == Event {
        let holder = MobiusHolder(controller: controller, connectable: AnyConnectable(connectable))

        objc_setAssociatedObject(
            self,
            .init("Mobius-Controller-Holder-Key"),
            holder,
            .OBJC_ASSOCIATION_RETAIN
        )

        return AnonymousDisposable {
            holder.dispose()
        }
    }
}

private final class MobiusHolder<Model, Event, Effect> {
    private let controller: MobiusController<Model, Event, Effect>

    init(
        controller: MobiusController<Model, Event, Effect>,
        connectable: AnyConnectable<Model, Event>
    ) {
        self.controller = controller
        controller.connectView(WeakConnectable(connectable: connectable))
        controller.start()
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

private final class WeakConnectable<Model, Event>: Connectable {
    weak var connectable: AnyConnectable<Model, Event>?
    var connection: Connection<Model>?

    init(connectable: AnyConnectable<Model, Event>) {
        self.connectable = connectable
    }

    func connect(_ consumer: @escaping (Event) -> Void) -> Connection<Model> {
        self.connection = connectable?.connect(consumer)
        return Connection(
            acceptClosure: { [weak connection] model in
                connection?.accept(model)
            },
            disposeClosure: { [weak connection] in
                connection?.dispose()
            }
        )
    }

    deinit {
        connection?.dispose()
    }
}

#endif
