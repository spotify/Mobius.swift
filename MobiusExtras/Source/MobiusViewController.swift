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
    /// The `MobiusController` will be started when `viewDidAppear` is called, and be stopped when
    /// `viewDidDisappear` is called. This function returns a `Disposable`, which can be disposed to stop the
    /// `MobiusController` early.
    ///
    /// Note: You should not be calling `start`, `connectView`, `stop`, or `disconnectView` on the `MobiusController`
    /// when using this extension.
    ///
    /// Note: Calling this method will add a `UIViewController` as a child of the current `UIViewController`. A subview
    /// will also be added to the current `UIViewController`'s view.
    ///
    /// - Parameter controller: The `MobiusController` that should be attached
    /// - Parameter connectable: The `Connectable` which should be connected to `controller`
    @discardableResult
    func useMobius<Model, Event, Effect, Conn: Connectable>(
        controller: MobiusController<Model, Event, Effect>,
        connectable: Conn
    ) -> Disposable where Conn.Input == Model, Conn.Output == Event {
        let holder = MobiusHolder(controller: controller, connectable: connectable)

        addChild(holder)
        view.addSubview(holder.view)
        holder.didMove(toParent: self)

        return AnonymousDisposable {
            holder.dispose()
        }
    }
}

private final class MobiusHolder<Model, Event, Effect>: UIViewController {
    private let controller: MobiusController<Model, Event, Effect>
    private var connectable: UnownedConnectable<Model, Event>

    init<Conn: Connectable>(
        controller: MobiusController<Model, Event, Effect>,
        connectable: Conn
    ) where Conn.Input == Model, Conn.Output == Event {
        self.controller = controller
        self.connectable = UnownedConnectable(connectable: connectable)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = UIView(frame: .zero)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !controller.running {
            controller.connectView(connectable)
            controller.start()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dispose()
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

private final class UnownedConnectable<Model, Event>: Connectable {
    private let _connect: (@escaping Consumer<Event>) -> Connection<Model>

    init<Conn: Connectable>(
        connectable: Conn
    ) where Conn.Input == Model, Conn.Output == Event {
        let unownedConnectable = connectable as AnyObject
        self._connect = { [unowned unownedConnectable] in
            // swiftlint:disable force_cast
            (unownedConnectable as! Conn).connect($0)
        }
    }

    func connect(_ consumer: @escaping Consumer<Event>) -> Connection<Model> {
        return _connect(consumer)
    }
}
#endif
