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

import Foundation
import MobiusCore
import MobiusExtras
import Nimble
import Quick

final class MobiusViewControllerTests: QuickSpec {
    override func spec() {
        context("View Controller using Mobius") {
            it("starts the Mobius Controller when the View Controller is initialized") {
                let viewController = ViewController(onModelChange: { _ in })

                expect(viewController.controller.running).to(beTrue())
            }

            it("stops the Mobius Controller when the View Controller is deinitialized") {
                var viewController: ViewController? = ViewController(onModelChange: { _ in })
                let controller = viewController!.controller

                viewController = nil

                expect(controller.running).to(beFalse())
            }

            it("stops the Mobius Controller when the View Controller's connection is disposed") {
                let viewController = ViewController(onModelChange: { _ in })

                viewController.connection.dispose()
                expect(viewController.controller.running).to(beFalse())
                expect(viewController.children.count).to(equal(0))
            }

            it("forwards model changes to `onModelChange`") {
                var model = ""
                let viewController = ViewController(onModelChange: { newModel in
                    model = newModel
                })

                viewController.connection.accept("1")
                viewController.connection.accept("2")
                viewController.connection.accept("3")

                expect(model).toEventually(equal("123"))
            }
        }
    }
}

private let update = Update<String, String, String> { model, event in
    .next(model + event)
}
private let effectHandler = EffectRouter<String, String>().asConnectable
private class ViewController: UIViewController {
    let controller = Mobius.loop(update: update, effectHandler: effectHandler)
        .makeController(from: "")
    var connection: Connection<String>!

    init(onModelChange: @escaping (String) -> Void) {
        super.init(nibName: nil, bundle: nil)
        connection = useMobius(
            controller: controller,
            modelChanged: onModelChange
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
