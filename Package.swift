// swift-tools-version: 6.0
import PackageDescription

var targets: [Target] = [
    .target(name: "AntiAITunesCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
    .testTarget(
        name: "AntiAITunesCoreTests",
        dependencies: ["AntiAITunesCore", .product(name: "GRDB", package: "GRDB.swift")]),
]
var products: [Product] = [
    .library(name: "AntiAITunesCore", targets: ["AntiAITunesCore"])
]

// The app needs AppKit and SwiftUI. Leaving it out elsewhere lets the core package build and test on Linux.
#if os(macOS)
    targets.append(.executableTarget(name: "AntiAITunes", dependencies: ["AntiAITunesCore"], path: "App"))
    products.append(.executable(name: "AntiAITunes", targets: ["AntiAITunes"]))
#endif

let package = Package(
    name: "AntiAITunes",
    platforms: [.macOS(.v14)],
    products: products,
    dependencies: [.package(url: "https://github.com/groue/GRDB.swift", from: "7.12.0")],
    targets: targets
)
