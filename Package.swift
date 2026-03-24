// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MinistryScheduler",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MinistryScheduler", targets: ["MinistryScheduler"])
    ],
    targets: [
        .executableTarget(
            name: "MinistryScheduler",
            path: ".",
            exclude: [
                "dist",
                "packaging",
                "scripts",
                "package_app.sh"
            ],
            sources: [
                "MinistrySchedulerApp.swift",
                "Models.swift",
                "SchedulerStore.swift",
                "ContentView.swift"
            ]
        )
    ]
)
