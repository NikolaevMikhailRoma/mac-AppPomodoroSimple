// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15)],
    targets: [
        // Logic only. No AppKit, no SwiftUI — this is what the tests import.
        .target(name: "PomodoroCore"),

        // UI only. Everything visual lives here, including config.json.
        .executableTarget(
            name: "Pomodoro",
            dependencies: ["PomodoroCore"],
            resources: [.copy("Resources/config.json")]
        ),

        .testTarget(
            name: "PomodoroTests",
            dependencies: ["PomodoroCore"]
        ),
    ]
)
