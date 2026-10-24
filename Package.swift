// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"]),
        // The iPhone app (ios/) builds on the same logic.
        .library(name: "PomodoroCore", targets: ["PomodoroCore"]),
        .library(name: "PomodoroConfig", targets: ["PomodoroConfig"]),
    ],
    targets: [
        // Логика. Ни AppKit, ни SwiftUI, ни одного цвета — это импортируют тесты.
        .target(name: "PomodoroCore"),

        // Форма config.json и его загрузка. Сам файл лежит здесь же, ресурсом.
        .target(
            name: "PomodoroConfig",
            dependencies: ["PomodoroCore"],
            resources: [.copy("Resources/config.json")]
        ),

        // Интерфейс. Всё видимое живёт здесь, разложено по поверхностям.
        .executableTarget(
            name: "Pomodoro",
            dependencies: ["PomodoroCore", "PomodoroConfig"]
        ),

        .testTarget(
            name: "PomodoroTests",
            dependencies: ["PomodoroCore", "PomodoroConfig"]
        ),
    ]
)
