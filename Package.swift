// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BarkDesk",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BarkCore", targets: ["BarkCore"]),
        .executable(name: "notify", targets: ["NotifyCLI"]),
        .executable(name: "BarkDesk", targets: ["BarkDesk"]),
    ],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .target(name: "BarkCore", dependencies: ["CSQLite"]),
        .executableTarget(name: "NotifyCLI", dependencies: ["BarkCore"]),
        .executableTarget(name: "BarkDesk", dependencies: ["BarkCore"]),
        .testTarget(name: "BarkCoreTests", dependencies: ["BarkCore"]),
    ]
)
