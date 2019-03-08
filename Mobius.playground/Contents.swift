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
import MobiusExtras
import MobiusTest

MobiusHooks.setErrorHandler { message, _, _ in
    print("An error occured: \(message)")
}

enum MyEvent {
    case increment
    case decrement
}

enum MyEffect {
    case reportErrorNegative
}

enum MyLoopTypes: LoopTypes {
    typealias Model = Int
    typealias Event = MyEvent
    typealias Effect = MyEffect
}

func update(model: Int, event: MyEvent) -> Next<Int, MyEffect> {
    switch event {
    case .increment:
        return .next(model + 1)

    case .decrement where model <= 0:
        return .dispatchEffects([.reportErrorNegative])

    case .decrement:
        return .next(model - 1)
    }
}

var loop: MobiusLoop<MyLoopTypes>!

func runTest(_ loop: MobiusLoop<MyLoopTypes>) {
    loop.addObserver { model in
        print("\(model)")
    }

    loop.dispatchEvent(.increment)
    loop.dispatchEvent(.decrement)
    loop.dispatchEvent(.decrement)
    loop.dispatchEvent(.decrement)
}

// ----------------------------------------------------------------------------

print("----\nLoop Demo\n----")

struct MyEffectHandlerFromProtocol: Connectable {
    typealias InputType = MyEffect
    typealias OutputType = MyEvent

    func connect(_ consumer: @escaping (MyEvent) -> Void) -> Connection<MyEffect> {
        return Connection<MyEffect>(acceptClosure: accept, disposeClosure: dispose)
    }

    func accept(_ effect: MyEffect) {
        switch effect {
        case .reportErrorNegative:
            print("error!")
        }
    }

    func dispose() {}
}

loop = Mobius.loop(update: update, effectHandler: MyEffectHandlerFromProtocol()).start(from: 1)
runTest(loop)

// ----------------------------------------------------------------------------

class AnimalLoopTypes: LoopTypes {
    typealias Model = Int
    typealias Event = String
    typealias Effect = String
}

class BarkEffectHandler: ActionConnectable<String, String>, EffectPredicate {
    typealias Effect = String

    init() {
        super.init {
            print("The dog goes: WOOOF!")
        }
    }

    func canAccept(_ effect: String) -> Bool {
        return effect == "Bark"
    }
}

class MooEffectHandler: ActionConnectable<String, String>, EffectPredicate {
    typealias Effect = String

    init() {
        super.init {
            print("The cow goes: Moo!")
        }
    }

    func canAccept(_ effect: String) -> Bool {
        return effect == "Moo"
    }
}

class CustomAnimalConnectable: ConsumerConnectable<String, String>, EffectPredicate {
    typealias Effect = String

    init() {
        super.init { (effect: String) in
            print("Some animals go: \(effect)!")
        }
    }

    func canAccept(_ effect: String) -> Bool {
        return effect != "Bark" && effect != "Moo"
    }
}

func animalUpdate(model: Int, event: String) -> Next<Int, String> {
    switch event {
    case "dog":
        return Next<Int, String>.dispatchEffects(["Bark"])
    case "cow":
        return Next<Int, String>.dispatchEffects(["Moo"])
    default:
        return Next<Int, String>.dispatchEffects(["Meow"])
    }
}

let connectable = EffectRouterBuilder<String, String>()
    .addConnectable(BarkEffectHandler())
    .addConnectable(BarkEffectHandler())
    .addConnectable(MooEffectHandler())
    .addConnectable(CustomAnimalConnectable())
    .build()

// This queue is only used in order to make sure that the playground does not terminate before all events and effects
// have been handled
let serialQueue = DispatchQueue(label: "playground print queue")
var animalBuilder: Mobius.Builder<AnimalLoopTypes> = Mobius.loop(update: animalUpdate, effectHandler: connectable)
animalBuilder = animalBuilder.withEventQueue(serialQueue) // Not recommended. Please do not do this
animalBuilder = animalBuilder.withEffectQueue(serialQueue) // Not recommended. Please do not do this
let animalLoop = animalBuilder.start(from: 0)

print("\n----\nEffectRouterBuilder Demo\n----")
animalLoop.dispatchEvent("cat")
animalLoop.dispatchEvent("dog")
animalLoop.dispatchEvent("cow")

serialQueue.sync {
    // Leave empty. This is only here to make sure that the events and effects have been processed before the
    // playground terminates
}

// ----------------------------------------------------------------------------
// Shows a suggestion on how to connect two loops
// The idea here is that we have an "Item page" which consists of a list of items
// that the user can add to a cart
// Similarly there is a "Cart page" which consists of the added items and the
// added amount.
// Each page contains a loop and we have identified a need for them to connect
//
// The principle behind the solution is that that for each of the loops, the
// task of updating the other loop is considered a "side-effect" and thus the
// code bridging the loops goes into "effect handlers".
// This approach has the added benefit of the adapter effect handlers being true
// adapters in the sense that they translate one set of domain effects to the other
// domains events and vice versa
//
// Behaviour definition:
//  The item page shows the amount added in the cart and allows you to add one of an item to the cart
//  The cart page shows the amount already added
// Flow of data:
//  Pressing add in item page -> increase count in cart page
//  Updated amount in cart -> update number of items in item page

// Definition of an item. Uninteresting but neccessary
struct Item: Hashable {
    let identifier: String
    static func == (lhs: Item, rhs: Item) -> Bool {
        return true
    }

    func hash(into hasher: inout Hasher) {}
}

// Definition of ItemPage loop
enum ItemPageEvent {
    case addPressed(Item) // On "add" button press
    case changeAmountOfItemsAdded(Item, Int) // Whenever the cart page changes
}

enum ItemPageEffect: Hashable {
    case increaseItemInCart(Item) // Effect telling the cart to update
}

struct ItemPageModel {
    let itemsOnSale: [Item: Int]
}

enum ItemPageLoopTypes: LoopTypes {
    typealias Model = ItemPageModel
    typealias Event = ItemPageEvent
    typealias Effect = ItemPageEffect
}

func itemPageUpdate(model: ItemPageModel, event: ItemPageEvent) -> Next<ItemPageModel, ItemPageEffect> {
    switch event {
    case .changeAmountOfItemsAdded(let (item, amount)):
        var items = model.itemsOnSale
        items[item] = amount
        let nextModel = ItemPageModel(itemsOnSale: items)
        return Next<ItemPageModel, ItemPageEffect>.next(nextModel)
    case let .addPressed(item):
        return .dispatchEffects([.increaseItemInCart(item)])
    }
}

// Definition and creation of the CartPage loop
enum CartPageEvent {
    case increaseByOne(Item) // Notifies that an update by one happened
}

enum CartPageEffect: Hashable {
    case cartChanged(Item, Int)
}

struct CartPageModel {
    let itemsInCart: [Item: Int]
}

enum CartPageLoopTypes: LoopTypes {
    typealias Model = CartPageModel
    typealias Event = CartPageEvent
    typealias Effect = CartPageEffect
}

func cartPageUpdate(model: CartPageModel, event: CartPageEvent) -> Next<CartPageModel, CartPageEffect> {
    if case let .increaseByOne(item) = event {
        var items = model.itemsInCart
        let count = (items[item] ?? 0) + 1
        items[item] = count
        let nextModel = CartPageModel(itemsInCart: items)
        return .next(nextModel, effects: [.cartChanged(item, count)])
    }
    return .noChange
}

// Loop creation

class ItemPageEffectHandler: ConnectableClass<ItemPageEffect, ItemPageEvent> {
    private var cartPageEventConsumer: Consumer<CartPageEvent>?

    func setCartPageEventConsumer(_ consumer: Consumer<CartPageEvent>?) {
        cartPageEventConsumer = consumer
    }

    override func handle(_ input: ItemPageEffect) {
        if case let .increaseItemInCart(item) = input {
            NSLog("------------")
            cartPageEventConsumer?(.increaseByOne(item))
        }
    }
}

class CartPageEffectHandler: ConnectableClass<CartPageEffect, CartPageEvent> {
    private var itemPageEventConsumer: Consumer<ItemPageEvent>?

    func setItemPageEventConsumer(_ consumer: Consumer<ItemPageEvent>?) {
        itemPageEventConsumer = consumer
    }

    override func handle(_ input: CartPageEffect) {
        if case let .cartChanged(item, amount) = input {
            itemPageEventConsumer?(.changeAmountOfItemsAdded(item, amount))
        }
    }
}

// Create ItemPageLoop
let itemQueue = DispatchQueue(label: "itemPageQueue") // Not needed unless in playground
let itemPageEffectHandler = ItemPageEffectHandler()
let initialItemPageModel = ItemPageModel(itemsOnSale: [:]) // Just for demo
var itemPageLoopBuilder: Mobius.Builder<ItemPageLoopTypes> = Mobius.loop(update: itemPageUpdate, effectHandler: itemPageEffectHandler)
itemPageLoopBuilder = itemPageLoopBuilder.withEventQueue(itemQueue)
itemPageLoopBuilder = itemPageLoopBuilder.withEffectQueue(itemQueue)
let itemPageLoop = itemPageLoopBuilder.start(from: initialItemPageModel)

// Create CartPageLoop
let cartQueue = DispatchQueue(label: "cartPageQueue") // Not needed unless in playground
let cartPageEffectHandler = CartPageEffectHandler()
let initalCartPageModel = CartPageModel(itemsInCart: [:]) // Just for demo
var cartPageLoopBuilder: Mobius.Builder<CartPageLoopTypes> = Mobius.loop(update: cartPageUpdate, effectHandler: cartPageEffectHandler)
cartPageLoopBuilder = cartPageLoopBuilder.withEventQueue(cartQueue)
cartPageLoopBuilder = cartPageLoopBuilder.withEffectQueue(cartQueue)
let cartPageLoop = cartPageLoopBuilder.start(from: CartPageModel(itemsInCart: [:]))

// Make sure to keep a weak reference to the other loop
// NOTE: Any consumer of events will do. This means that the cartPageLoop does not really need to be exposed to the
// itemPageEffectHandler but can be passed anonymously
itemPageEffectHandler.setCartPageEventConsumer { [weak cartPageLoop] (event: CartPageEvent) in
    cartPageLoop?.dispatchEvent(event)
}

// Make sure to keep a weak reference to the other loop
// NOTE: Any consumer of events will do. This means that the itemPageLoop does not really need to be exposed to the
// cartPageEffectHandler but can be passed anonymously
cartPageEffectHandler.setItemPageEventConsumer { [weak itemPageLoop] (event: ItemPageEvent) in
    itemPageLoop?.dispatchEvent(event)
}

// Test
print("----")
let testItem = Item(identifier: "test")
itemPageLoop.addObserver { (model: ItemPageModel) in
    print("Item page contains: \(model.itemsOnSale)")
}

cartPageLoop.addObserver { (model: CartPageModel) in
    print("Cart contains: \(model.itemsInCart)")
}

itemPageLoop.dispatchEvent(.addPressed(testItem)) // This would be done via the UI

cartQueue.sync {
    // Leave empty. Here to ensure that the playground does not exit early
}

itemQueue.sync {
    // Leave empty. Here to ensure that the playground does not exit early
}
