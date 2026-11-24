// swift-tools-version:5.9
// Not the app build. This compiles only the platform-neutral logic so its unit
// tests can run with `swift test` on Linux/macOS without Xcode. The app itself is
// built from project.yml (XcodeGen).
import PackageDescription

let package = Package(
    name: "Itadaki",
    targets: [
        .target(
            name: "Itadaki",
            path: "Itadaki",
            sources: [
                "Models/Dish.swift",
                "Models/MenuSection.swift",
                "Models/Order.swift",
                "Models/Romaji.swift",
                "Models/PriceFormatter.swift",
                "Services/MenuAnalyzer.swift",
                "Services/MenuPrompt.swift",
                "Services/ClaudeMenuAnalyzer.swift",
                "Services/MockMenuAnalyzer.swift",
                "Services/CropMath.swift",
                "Services/TilePlan.swift",
            ]
        ),
        .testTarget(
            name: "ItadakiTests",
            dependencies: ["Itadaki"],
            path: "ItadakiTests"
        ),
    ]
)
