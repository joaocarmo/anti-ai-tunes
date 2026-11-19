// swift-tools-version: 6.0
import PackageDescription

var targets: [Target] = [
    .target(name: "AntiAITunesCore"),
    .testTarget(name: "AntiAITunesCoreTests", dependencies: ["AntiAITunesCore"]),
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
    targets: targets
)
