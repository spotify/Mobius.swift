// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "Mobius",
    products: [
        .library(name: "MobiusCore", targets: ["MobiusCore"]),
        .library(name: "MobiusExtras", targets: ["MobiusExtras"]),
        .library(name: "MobiusNimble", targets: ["MobiusNimble"]),
        .library(name: "MobiusTest", targets: ["MobiusTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble", from: "8.0.0"),
        .package(url: "https://github.com/Quick/Quick", from: "2.0.0"),
    ],
    targets: [
        .target(name: "MobiusCore", path: "MobiusCore/Source"),
        .target(name: "MobiusExtras", dependencies: ["MobiusCore"], path: "MobiusExtras/Source"),
        .target(name: "MobiusNimble", dependencies: ["MobiusCore", "MobiusTest", "Nimble"], path: "MobiusNimble/Source"),
        .target(name: "MobiusTest", dependencies: ["MobiusCore"], path: "MobiusTest/Source"),

        .testTarget(name: "MobiusCoreTests", dependencies: ["MobiusCore", "Nimble", "Quick"], path: "MobiusCore/Test"),
        .testTarget(name: "MobiusExtrasTests", dependencies: ["MobiusExtras", "Nimble", "Quick"], path: "MobiusExtras/Test"),
        .testTarget(name: "MobiusNimbleTests", dependencies: ["MobiusNimble", "Quick"], path: "MobiusNimble/Test"),
        .testTarget(name: "MobiusTestTests", dependencies: ["MobiusTest", "Quick"], path: "MobiusTest/Test"),
    ],
    swiftLanguageVersions: [.v5]
)
