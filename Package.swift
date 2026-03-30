// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "agentch",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "agentch",
            path: "agentch_pkg/agentch"
        ),
    ]
)
