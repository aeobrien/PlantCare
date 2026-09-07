// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PlantCareCLI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PlantCareCore", targets: ["PlantCareCore"]),
        .executable(name: "plantcare-cli", targets: ["plantcare-cli"])
    ],
    targets: [
        .target(
            name: "PlantCareCore",
            path: "PlantCare",
            sources: [
                "Services/OpenAIService.swift",
                "Models/Models.swift",
                "Models/AIModels.swift"
            ]
        ),
        .executableTarget(
            name: "plantcare-cli",
            dependencies: ["PlantCareCore"],
            path: "cli/PlantCareCLI"
        )
    ]
)
