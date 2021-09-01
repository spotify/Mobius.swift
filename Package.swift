// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Mobius",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_12),
        .tvOS(.v10),
        .watchOS(.v3),
    ],
    products: [
        .library(name: "MobiusCore", targets: ["MobiusCore"]),
        .library(name: "MobiusExtras", targets: ["MobiusExtras"]),
        .library(name: "MobiusNimble", targets: ["MobiusNimble"]),
        .library(name: "MobiusTest", targets: ["MobiusTest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble", from: "9.0.1"),
        .package(url: "https://github.com/Quick/Quick", from: "3.1.2"),
    ],
    targets: [
        .target(name: "MobiusCore", path: "MobiusCore/Source"),
        .target(name: "MobiusExtras", dependencies: ["MobiusCore"], path: "MobiusExtras/Source"),
        .target(name: "MobiusNimble", dependencies: ["MobiusCore", "MobiusTest", "Nimble"], path: "MobiusNimble/Source"),
        .target(name: "MobiusTest", dependencies: ["MobiusCore"], path: "MobiusTest/Source"),
        .target(name: "MobiusThrowableAssertion", path: "MobiusThrowableAssertion/Source"),

        .testTarget(
            name: "MobiusCoreTests",
            dependencies: ["MobiusCore", "Nimble", "Quick", "MobiusThrowableAssertion"],
            path: "MobiusCore/Test"
        ),
        .testTarget(
            name: "MobiusExtrasTests",
            dependencies: ["MobiusCore", "MobiusExtras", "Nimble", "Quick", "MobiusThrowableAssertion"],
            path: "MobiusExtras/Test"
        ),
        .testTarget(name: "MobiusNimbleTests", dependencies: ["MobiusNimble", "Quick"], path: "MobiusNimble/Test"),
        .testTarget(name: "MobiusTestTests", dependencies: ["MobiusTest", "Quick", "Nimble"], path: "MobiusTest/Test"),
    ],
    swiftLanguageVersions: [.v5]
)
