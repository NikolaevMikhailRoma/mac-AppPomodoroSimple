// swift-tools-version: 6.1
import PackageDescription

// src/ is what the Mac and the iPhone share; mac/ is the Mac's own. The
// iPhone app (ios/) and Android (android/) build on src/ from their own folders.
let package = Package(
    name: "Pomodoro",
    platforms: [.macOS(.v15), .iOS(.v17)],
    products: [
        .executable(name: "Pomodoro", targets: ["Pomodoro"]),
        .library(name: "PomodoroCore", targets: ["PomodoroCore"]),
        .library(name: "PomodoroConfig", targets: ["PomodoroConfig"]),
        .library(name: "PomodoroUI", targets: ["PomodoroUI"]),
    ],
    targets: [
        // Логика. Ни AppKit, ни SwiftUI, ни одного цвета — это импортируют тесты.
        .target(name: "PomodoroCore", path: "src/core"),

        // Форма config.json и его загрузка. Сам файл лежит здесь же, ресурсом; Android берёт его из той же папки.
        .target(
            name: "PomodoroConfig",
            dependencies: ["PomodoroCore"],
            path: "src/config",
            resources: [.copy("Resources/config.json")]
        ),

        // Экраны на SwiftUI, общие для Мака и iPhone: таймер, настройки.
        .target(
            name: "PomodoroUI",
            dependencies: ["PomodoroCore", "PomodoroConfig"],
            path: "src/ui"
        ),

        // Мак: строка меню, окна, системные службы.
        .executableTarget(
            name: "Pomodoro",
            dependencies: ["PomodoroCore", "PomodoroConfig", "PomodoroUI"],
            path: "mac",
            exclude: ["Info.plist", "Resources"]
        ),

        .testTarget(
            name: "PomodoroTests",
            dependencies: ["PomodoroCore", "PomodoroConfig"],
            path: "tests"
        ),
    ]
)
