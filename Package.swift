// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeltaCore",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "DeltaCore", targets: ["DeltaCore", "CDeltaCore"]),
    ],
    dependencies: [
        .package(name: "ZIPFoundation", url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMinor(from: "0.9.11"))
    ],
    targets: [
        .target(
            name: "CDeltaCore",
            dependencies: [],
            path: "DeltaCore",
            exclude: [
                "Delta.swift",
                "Cores",
                "Emulator Core/EmulatorCore.swift",
                "Emulator Core/Video",
                "Emulator Core/Audio/AudioManager.swift",
                "Emulator Core/Audio/RingBuffer.swift",
                "Extensions",
                "Filters",
                "Game Controllers",
                "Model",
                "Protocols",
                "Supporting Files",
                "Types/ExtensibleEnums.swift",
                "UI"
            ],
            sources: [
                "DeltaTypes.m",
                "Emulator Core/Audio/DLTAMuteSwitchMonitor.m",
            ],
            publicHeadersPath: "include"
        ),
        .target(
            name: "DeltaCore",
            dependencies: ["CDeltaCore", "ZIPFoundation"],
            path: "DeltaCore",
            exclude: [
                "DeltaTypes.m",
                "Emulator Core/Audio/DLTAMuteSwitchMonitor.m",
                "Supporting Files/Info.plist",
            ],
            resources: [
                .copy("Supporting Files/KeyboardGameController.deltamapping"),
                .copy("Supporting Files/MFiGameController.deltamapping"),
            ],
            cSettings: [
                .define("GLES_SILENCE_DEPRECATION"),
                .define("CI_SILENCE_GL_DEPRECATION")
            ]
        ),
    ]
)
