// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentCh",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "AgentCh",
            path: "AgentCh/AgentCh"
        ),
        .testTarget(
            name: "AgentChTests",
            dependencies: ["AgentCh"],
            path: "AgentCh/AgentChTests"
        ),
    ]
)
