// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HotelDuskDuo",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HotelDuskDuoKit",
            targets: ["HotelDuskDuoKit"]
        ),
        .executable(
            name: "HotelDuskDuoApp",
            targets: ["HotelDuskDuoApp"]
        )
    ],
    targets: [
        .target(
            name: "HotelDuskDuoKit",
            exclude: ["Resources/Shaders"],
            resources: [
                .process("Resources/Images"),
                .process("Resources/GameText.json"),
                .process("Resources/JigsawDialogue.json"),
                .copy("Resources/Original/Scripts"),
                .copy("Resources/Original/Audio"),
                .copy("Resources/RecordedMusic"),
                .copy("Resources/Original/GameData"),
                .copy("Resources/OriginalAnimations"),
                .copy("Resources/OriginalTextures"),
                .copy("Resources/OriginalModels"),
                .copy("Resources/OriginalBitmaps"),
                .copy("Resources/EnhancedArtwork"),
                .copy("Metal")
            ]
        ),
        .executableTarget(
            name: "HotelDuskDuoApp",
            dependencies: ["HotelDuskDuoKit"]
        ),
        .testTarget(
            name: "HotelDuskDuoTests",
            dependencies: ["HotelDuskDuoKit"]
        )
    ]
)
