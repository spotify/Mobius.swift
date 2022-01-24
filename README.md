![Mobius.swift](https://github.com/spotify/Mobius.swift/wiki/mobius-logo.svg)

[![codecov](https://codecov.io/gh/spotify/Mobius.swift/branch/master/graph/badge.svg)](https://codecov.io/gh/spotify/Mobius.swift)
[![License](https://img.shields.io/github/license/spotify/Mobius.swift.svg)](LICENSE)

Mobius is a functional reactive framework for managing state evolution and side-effects. It
emphasizes separation of concerns, testability, and isolating stateful parts of the code.

Mobius.swift is the Swift and Apple ecosystem focused implementation of the original
[Mobius Java framework](https://github.com/spotify/mobius). To learn more, see the [wiki](/../../wiki) for a user guide. You can also watch a [talk from an Android @Scale introducing Mobius](https://www.facebook.com/atscaleevents/videos/2025571921049235/).

This repository contains the core Mobius framework and add-ons for common development scenarios and testing.

## Compatibility
| Environment | details     |
| ----------- |-------------|
| 📱 iOS      | 10.0+      |
| 🛠 Xcode    | 12.0+       |
| 🐦 Language | Swift 5.0  |

## Installation

Mobius can be built for all Apple platforms using the Swift Package Manager.

Add the following entry to your `Package.swift`:
```swift
.package(url: "https://github.com/spotify/Mobius.swift", from: "0.5.0")
```

## Mobius in Action - Building a Counter

The goal of Mobius is to give you better control over your application state. You can think of your state as a snapshot of all the current values of the variables in your application. In Mobius, we encapsulate all of the state in a data structure which we call the *Model*.

The *Model* can be represented by whatever type you like. In this example we’ll be building a simple counter, so all of our state can be contained in an `Int`:

```swift
typealias CounterModel = Int
```

Mobius does not let you manipulate the state directly. In order to change the state, you have to send the framework messages saying what you want to do. We call these messages *Events*. In our case, we’ll want to increment and decrement our counter. Let’s use an `enum` to define these cases:
```swift
enum CounterEvent {
    case increment
    case decrement
}
```

Now that we have a *Model* and some *Event*s, we’ll need to give Mobius a set of rules which it can use to update the state on our behalf. We do this by giving the framework a function which will be sequentially called with every incoming *Event* and the most recent *Model*, in order to generate the next *Model*:
```swift
func update(model: CounterModel, event: CounterEvent) -> CounterModel {
    switch event {
    case .increment: return model + 1
    case .decrement: return model - 1
    }
}
```

With these building blocks, we can start to think about our applications as transitions between discrete states in response to events. But we believe there still one piece missing from the puzzle – namely the side effects which are associated with moving between states. For instance, pressing a “refresh” button might put our application into a “loading” state, with the side effect of also fetching the latest data from our backend.

In Mobius, we aptly call these side effects *Effect*s. In the case of our counter, let’s say that when the user tries to decrement below 0, we play a sound effect instead. Let’s create an `enum` that represents all the possible effects (which in this case is only one):
```swift
enum CounterEffect {
    case playSound
}
```

We’ll now need to augment our `update` function to also return a set of effects associated with certain state transitions. This looks like:

```swift
func update(model: CounterModel, event: CounterEvent) -> Next<CounterModel, CounterEffect> {
    switch event {
    case .increment: 
        return .next(model + 1)
    case .decrement:
        if model == 0 {
            return .dispatchEffects([.playSound])
        } else {
            return .next(model - 1)
        }
    }
}
```

Mobius sends each of the effects you return in any state transition to something called an *Effect Handler*. Let’s make one of those now:
```swift
import AVFoundation

private func beep() {
    AudioServicesPlayAlertSound(SystemSoundID(1322))
}

let effectHandler = EffectRouter<CounterEffect, CounterEvent>()
    .routeCase(CounterEffect.playSound).to { beep() }
    .asConnectable
```

Now that we have all the pieces in place, let’s tie it all together:
```swift
let application = Mobius.loop(update: update, effectHandler: effectHandler)
    .start(from: 0)
```


Let’s start using our counter:
```swift
application.dispatchEvent(.increment) // Model is now 1
application.dispatchEvent(.decrement) // Model is now 0
application.dispatchEvent(.decrement) // Sound effect plays! Model is still 0
```

This covers the fundamentals of Mobius. To learn more, head on over to our [wiki](/../../wiki).

## Code of Conduct

This project adheres to the [Open Code of Conduct][code-of-conduct]. By participating, you are expected to honor this code.

[code-of-conduct]: https://github.com/spotify/code-of-conduct/blob/master/code-of-conduct.md
