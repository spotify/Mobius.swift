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

import Foundation
import MobiusCore
import MobiusExtras
import Nimble
import Quick

final class MobiusViewControllerTests: QuickSpec {
    override func spec() {
        context("View Controller using Mobius") {
            it("starts the Mobius Controller when viewDidAppear is called") {
                let viewController = ViewController(onModelChange: { _ in })

                expect(viewController.children.count).to(equal(1))
                guard let child = viewController.children.first else {
                    fail()
                    return
                }

                child.viewDidAppear(false)

                expect(viewController.controller.running).to(beTrue())
                child.viewDidDisappear(false)
            }

            it("stops the Mobius Controller when viewDidDisappear is called") {
                let viewController = ViewController(onModelChange: { _ in })

                guard let child = viewController.children.first else {
                    fail()
                    return
                }

                child.viewDidAppear(false)
                child.viewDidDisappear(false)

                expect(viewController.controller.running).to(beFalse())
            }

            it("stops the Mobius Controller when disposed") {
                let viewController = ViewController(onModelChange: { _ in })
                guard let disposable = viewController.disposable else {
                    fail()
                    return
                }
                disposable.dispose()

                expect(viewController.controller.running).to(beFalse())
            }

            it("forwards model changes to `onModelChange`") {
                var model = ""
                let viewController = ViewController(onModelChange: { newModel in
                    model = newModel
                })

                guard let child = viewController.children.first else {
                      fail()
                      return
                }

                child.viewDidAppear(false)
                viewController.output?("1")
                viewController.output?("2")
                viewController.output?("3")

                expect(model).toEventually(equal("123"))
                child.viewDidDisappear(false)
            }
        }
    }
}

private let update = Update<String, String, String> { model, event in
    .next(model + event)
}
private let effectHandler = EffectRouter<String, String>().asConnectable
private class ViewController: UIViewController, Connectable {
    let controller = Mobius.loop(update: update, effectHandler: effectHandler)
        .makeController(from: "")
    let onModelChange: Consumer<String>
    var disposable: Disposable?
    var output: Consumer<String>?

    init(onModelChange: @escaping Consumer<String>) {
        self.onModelChange = onModelChange
        super.init(nibName: nil, bundle: nil)

        self.disposable = useMobius(
            controller: controller,
            connectable: self
        )
    }

    func connect(_ consumer: @escaping (String) -> Void) -> Connection<String> {
        output = consumer
        return Connection(
            acceptClosure: self.onModelChange,
            disposeClosure: {}
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
