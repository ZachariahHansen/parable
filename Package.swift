// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Parable",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ParableCore", targets: ["ParableCore"]),
        .executable(name: "parable", targets: ["parable"]),
        .executable(name: "ParableApp", targets: ["ParableApp"]),
    ],
    targets: [
        // Everything that isn't UI lives here so a SwiftUI app can reuse it later.
        .target(name: "ParableCore"),
        .executableTarget(name: "parable", dependencies: ["ParableCore"]),
        .executableTarget(name: "ParableApp", dependencies: ["ParableCore"]),
    ]
)
