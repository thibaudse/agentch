// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "agentch",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "AgentIslandUI", targets: ["AgentIslandApp"]),
        .executable(name: "AgentIsland", targets: ["AgentIslandExecutable"])
    ],
    targets: [
        .target(name: "AgentIslandApp"),
        .executableTarget(
            name: "AgentIslandExecutable",
            dependencies: ["AgentIslandApp"],
            path: "Sources/AgentIslandExecutable"
        )
    ]
)
