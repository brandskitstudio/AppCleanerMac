// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AppCleanerMac",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "AppCleanerMac",
            path: "Sources/AppCleanerMac",
            resources: [
                .process("Views/AppIcon.png")
            ]
        )
    ]
)
