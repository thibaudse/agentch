// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "agentch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AgentIsland", targets: ["AgentIslandApp"])
    ],
    targets: [
        .executableTarget(name: "AgentIslandApp")
    ]
)
