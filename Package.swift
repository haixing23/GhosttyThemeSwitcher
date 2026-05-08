// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GhosttyThemeSwitcher",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "GhosttyThemeSwitcher",
            targets: ["GhosttyThemeSwitcher"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "GhosttyThemeSwitcher",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "GhosttyThemeSwitcherTests",
            dependencies: ["GhosttyThemeSwitcher"]
        ),
    ]
)
