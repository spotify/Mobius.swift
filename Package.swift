// swift-tools-version:5.2
import PackageDescription

let depCasePaths: PackageDescription.Target.Dependency = .product(name: "CasePaths", package: "swift-case-paths")
let depQuick: PackageDescription.Target.Dependency = .product(name: "Quick", package: "Quick")
let depNimble: PackageDescription.Target.Dependency = .product(name: "Nimble", package: "Nimble")

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
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMinor(from: "0.10.1")),
        .package(url: "https://github.com/Quick/Nimble", from: "10.0.0"),
        .package(url: "https://github.com/Quick/Quick", from: "7.0.0"),
    ],
    targets: [
        .target(name: "MobiusCore", dependencies: [depCasePaths], path: "MobiusCore/Source"),
        .target(name: "MobiusExtras", dependencies: ["MobiusCore"], path: "MobiusExtras/Source"),
        .target(name: "MobiusNimble", dependencies: ["MobiusCore", "MobiusTest", depNimble], path: "MobiusNimble/Source"),
        .target(name: "MobiusTest", dependencies: ["MobiusCore"], path: "MobiusTest/Source"),
        .target(name: "MobiusThrowableAssertion", path: "MobiusThrowableAssertion/Source"),

        .testTarget(
            name: "MobiusCoreTests",
            dependencies: ["MobiusCore", "MobiusThrowableAssertion", depNimble, depQuick],
            path: "MobiusCore/Test"
        ),
        .testTarget(
            name: "MobiusExtrasTests",
            dependencies: ["MobiusCore", "MobiusExtras", "MobiusThrowableAssertion", depNimble, depQuick],
            path: "MobiusExtras/Test"
        ),
        .testTarget(name: "MobiusNimbleTests", dependencies: ["MobiusNimble", depQuick], path: "MobiusNimble/Test"),
        .testTarget(name: "MobiusTestTests", dependencies: ["MobiusTest", depNimble, depQuick], path: "MobiusTest/Test"),
    ],
    swiftLanguageVersions: [.v5]
)
