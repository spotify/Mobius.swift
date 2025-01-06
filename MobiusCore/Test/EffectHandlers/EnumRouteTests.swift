// Copyright Spotify AB.
// SPDX-License-Identifier: Apache-2.0

import MobiusCore
import Nimble
import Quick

private typealias Event = ()

private enum Effect {
    case justEffect
    case effectWithString(String)
    case effectWithTuple(left: String, right: Int)
}

private indirect enum List: Equatable {
    case singleton(String)
}

private func unwrap<Input, Parameters, Output>(
    effect: Input,
    usingRoute partialRouter: _PartialEffectRouter<Input, Parameters, Output>
) -> Parameters? {
    var parameters: Parameters?
    let handler = partialRouter
        .to { unwrappedParameters in
            parameters = unwrappedParameters
        }
        .asConnectable
        .connect { _ in }

    handler.accept(effect)
    handler.dispose()
    return parameters
}

class ParameterExtractionRouteTests: QuickSpec {
    override func spec() {
        context("Different types of enums being unwrapped") {
            it("supports routing to an effect with nothing to unwrap") {
                let route = EffectRouter<Effect, Never>()
                    .routeCase(Effect.justEffect)

                let result: Void? = unwrap(effect: .justEffect, usingRoute: route)

                expect(result).to(beVoid())
            }

            it("supports unwrapping an effect with a string") {
                let route = EffectRouter<Effect, Never>()
                    .routeCase(Effect.effectWithString)

                let result = unwrap(effect: .effectWithString("test"), usingRoute: route)

                expect(result).to(equal("test"))
            }

            it("supports unwrapping an effect with a tuple") {
                let route = EffectRouter<Effect, Never>()
                    .routeCase(Effect.effectWithTuple)

                if let (leftUnwrapped, rightUnwrapped) = unwrap(
                    effect: .effectWithTuple(left: "Test", right: 1),
                    usingRoute: route
                ) {
                    expect(leftUnwrapped).to(equal("Test"))
                    expect(rightUnwrapped).to(equal(1))
                } else {
                    fail("Unable to unwrap containing a tuple.")
                }
            }

            it("supports unwrapping an indirect type") {
                let route = EffectRouter<List, Never>()
                    .routeCase(List.singleton)

                let result = unwrap(effect: .singleton("Test"), usingRoute: route)

                expect(result).to(equal("Test"))
            }
        }
    }
}
