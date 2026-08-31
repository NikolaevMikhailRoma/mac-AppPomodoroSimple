// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15)],
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
