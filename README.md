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

## Usage
Pull in Mobius.swift as a dependency. Either as a submodule or using [Carthage](https://github.com/Carthage/Carthage).

Build the project and link with the frameworks.

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
