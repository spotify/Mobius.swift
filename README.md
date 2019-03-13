![Mobius.swift](https://github.com/spotify/mobius.swift/wiki/mobius-logo.png)

[![Carthage Compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.org/spotify/Mobius.swift.svg?branch=master)](https://travis-ci.org/spotify/Mobius.swift)
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
| 🛠 Xcode    | 10.1+       |
| 🐦 Language | Swift 4.2  |

## Usage in Your Project
Pull in Mobius.swift as a dependency. Either as a submodule or using [Carthage](https://github.com/Carthage/Carthage).

Build the project and link with the frameworks.

## Mobius in Action - Building a Counter

The goal of Mobius is to give you better control over your application state. You can think of your state as a snapshot of all the current values of the variables in your application. In Mobius, we encapsulate all of the state in a data-structure which we call the *Model*.

The *Model* can be represented by whatever type you like. In this example we'll be building a simple counter, so all of our state can be contained in an `Int`:

```swift
typealias CounterModel = Int
```

Mobius does not let you manipulate the state directly. In order to change the state, you have to send the framework messages saying what you want to do. We call these messages *Events*. In our case, we'll want to increment and decrement our counter. Let's use an `enum` to define these cases:
```swift
enum CounterEvent {
    case increment
    case decrement
}
```

Now that we have a *Model* and some *Event*s, we'll need to give Mobius a set of rules which it can use to update the state on our behalf. We do this by giving the framework a function which will be sequentially called with every incoming *Event* and the most recent *Model*, in order to generate the next *Model*:
```swift
func update(model: CounterModel, event: CounterEvent) -> CounterModel {
    switch event {
    case .increment: return model + 1
    case .decrement: return model - 1
    }
}
```

With these building blocks, we can start to think about our applications as transitions between discrete states in response to events. But we believe there still one piece missing from the puzzle - namely the side-effects which are associated with moving between states. For instance, pressing a "refresh" button might put our application into a "loading" state, with the side-effect of also fetching the latest data from our backend.

In Mobius, we aptly call these side-effects *Effect*s. In the case of our counter, let's say that when the user tries to decrement below 0, we play a sound effect instead. Let's create an `enum` that represents all the possible effects (which in this case is only one):
```swift
enum CounterEffect {
    case playSound
}
```

We'll now need to augment our `update` function to also return a set of effects associated with certain state transitions. This looks like:

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

Mobius sends each of the effects you return in any state transition to something called an *Effect Handler*. Let's make one of those now:
```swift
import AVFoundation
import MobiusExtras

class PlaySoundEffectHandler: ConnectableClass<CounterEffect, CounterEvent> {
    override func handle(_ input: CounterEffect) {
        AudioServicesPlayAlertSound(SystemSoundID(1322))
    }
    override func onDispose() {}
}
```

Now that we have all the pieces in place, let's tie it all together:
```swift
// For convenience, we put all our types in one enum
enum CounterLoopTypes: LoopTypes {
    typealias Event = CounterEvent
    typealias Effect = CounterEffect
    typealias Model = CounterModel
}
// And build a Mobius Loop!
let application: MobiusLoop<CounterLoopTypes> = Mobius
    .loop(update: update, effectHandler: PlaySoundEffectHandler())
    .start(from: 0)
```


Let's start using our counter:
```swift
application.dispatchEvent(.increment) // Model is now 1
application.dispatchEvent(.decrement) // Model is now 0
application.dispatchEvent(.decrement) // Sound effect plays! Model is still 0
```

This covers the fundamentals of Mobius. To learn more, head on over to our [wiki](/../../wiki).

## Status

Mobius.swift is in alpha status. We are beginning to use the framework internally and may still make breaking API changes. The abstractions for threading are the main thing we want to revisit before we feel confident in a 1.0 release. The core concepts of an `update` function with `Model`s, `Event`s, and `Effect`s are not going to change. Please note that this project may be combined with the [Mobius Java repository](https://github.com/spotify/mobius) in the near future.

## Development
1. Clone
1. Bootstrap the project
   ```shell
   ./Tools/bootstrap.sh
   ```
1. Open Mobius.xcodeproj using Xcode.
1. ????
1. Create a PR

## Code of Conduct

This project adheres to the [Open Code of Conduct][code-of-conduct]. By participating, you are expected to honor this code.

[code-of-conduct]: https://github.com/spotify/code-of-conduct/blob/master/code-of-conduct.md
