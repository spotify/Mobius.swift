

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

public extension Mobius.Builder {
    func makeLoopController(
        from initialModel: Model,
        initiate: Initiate<Model, Effect>? = nil,
        qos: DispatchQoS.QoSClass = .userInitiated
    ) -> MobiusLoopController<Model, Event, Effect> {
        return makeLoopController(from: initialModel, initiate: initiate, loopQueue: .global(qos: qos))
    }

    func makeLoopController(
        from initialModel: Model,
        initiate: Initiate<Model, Effect>? = nil,
        loopQueue: DispatchQueue,
        viewQueue: DispatchQueue = .main
    ) -> MobiusLoopController<Model, Event, Effect> {
        return MobiusLoopController(
            builder: self,
            initialModel: initialModel,
            initiate: initiate,
            loopQueue: loopQueue,
            viewQueue: viewQueue
        )
    }
}

public final class MobiusLoopController<Model, Event, Effect> {
    private let controller: MobiusController<Model, Event, Effect>

    init(
        builder: Mobius.Builder<Model, Event, Effect>,
        initialModel: Model,
        initiate: Initiate<Model, Effect>? = nil,
        loopQueue loopTargetQueue: DispatchQueue,
        viewQueue: DispatchQueue
    ) {
        self.controller = builder.makeController(
            from: initialModel,
            initiate: initiate,
            loopQueue: loopTargetQueue,
            viewQueue: viewQueue
        )
    }

    public var running: Bool { controller.running }

    public var model: Model { controller.model }

    public func replaceModel(model: Model) {
        controller.replaceModel(model)
    }

    public func start<Conn: Connectable>(connectable: Conn) where Conn.Input == Model, Conn.Output == Event {
        if !controller.running {
            controller.connectView(UnownedConnectable(connectable))
            controller.start()
        }
    }

    public func stop() {
        if controller.running {
            controller.stop()
            controller.disconnectView()
        }
    }

    deinit {
        stop()
    }
}

private final class UnownedConnectable<Model, Event>: Connectable {
    private let _connect: (@escaping Consumer<Event>) -> Connection<Model>

    init<Conn: Connectable>(
        _ connectable: Conn
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
