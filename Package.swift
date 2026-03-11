// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "agentch",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "AgentIsland", targets: ["AgentIslandApp"])
    ],
    targets: [
        .executableTarget(name: "AgentIslandApp")
    ]
)
