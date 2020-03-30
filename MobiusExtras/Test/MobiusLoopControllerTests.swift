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

import MobiusExtras
import MobiusCore
import Nimble
import Quick

final class MobiusLoopControllerTests: QuickSpec {
    override func spec() {
        context("MobiusLoopController") {
            it("does not hold a strong reference to its connectable") {
                var didDeinitialize = false
                var controllerHolder: ControllerHolder? = ControllerHolder(
                    controller: makeController(),
                    onDeinit: { didDeinitialize = true }
                )
                expect(controllerHolder?.controller.running).to(beTrue())

                controllerHolder = nil
                expect(didDeinitialize).to(beTrue())
            }

            it("Disconnects from its connectable when deinitialized") {
                let connectable = TestConnectable()
                var controller: MobiusLoopController? = makeController()

                controller?.start(connectable: connectable)
                expect(connectable.isConnected).to(beTrue())

                controller = nil
                expect(connectable.isConnected).toEventually(beFalse())
            }

            it("supports replacing the model") {
                let connectable = TestConnectable()
                let controller: MobiusLoopController = makeController()

                controller.replaceModel(model: 15)
                controller.start(connectable: connectable)
                expect(controller.model).to(equal(15))
                controller.stop()
            }

            it("supports observers") {
                let connectable = TestConnectable()
                let controller: MobiusLoopController = makeController()

                controller.start(connectable: connectable)
                expect(connectable.model).toEventually(equal(0))
                connectable.output?(15)
                expect(connectable.model).toEventually(equal(15))
                controller.stop()
            }

            it("is only running between starting and stopping") {
                let connectable = TestConnectable()
                let controller: MobiusLoopController = makeController()

                expect(controller.running).to(beFalse())
                controller.start(connectable: connectable)
                expect(controller.running).to(beTrue())
                controller.stop()
                expect(controller.running).to(beFalse())
            }
        }
    }
}

private func makeController() -> MobiusLoopController<Int, Int, Int> {
    return Mobius.loop(
        update: Update<Int, Int, Int>  { model, event in
            .next(model + event)
        },
        effectHandler: EffectRouter().asConnectable
    ).makeLoopController(from: 0)
}

private class TestConnectable: Connectable {
    var isConnected = false
    var model: Int = 0
    var output: Consumer<Int>?

    func connect(_ consumer: @escaping Consumer<Int>) -> Connection<Int> {
        self.isConnected = true
        self.output = consumer
        return Connection(
            acceptClosure: { [weak self] model in
                self?.model = model
            },
            disposeClosure: { [weak self] in
                self?.isConnected = false
            }
        )
    }
}

private class ControllerHolder: Connectable {
    let onDeinit: () -> Void
    let controller: MobiusLoopController<Int, Int, Int>

    init(
        controller: MobiusLoopController<Int, Int, Int>,
        onDeinit: @escaping () -> Void = {}
    ) {
        self.controller = controller
        self.onDeinit = onDeinit
        controller.start(connectable: self)
    }

    func connect(_ consumer: @escaping Consumer<Int>) -> Connection<Int> {
        return Connection(
            acceptClosure: { _ in },
            disposeClosure: {}
        )
    }

    deinit {
        onDeinit()
    }
}
