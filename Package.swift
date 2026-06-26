// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Transcribee",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "TranscribeeCore", targets: ["TranscribeeCore"]),
        .executable(name: "Transcribee", targets: ["TranscribeeApp"]),
        .executable(name: "TranscribeeCoreTests", targets: ["TranscribeeCoreTests"])
    ],
    targets: [
        .target(name: "TranscribeeCore"),
        .executableTarget(
            name: "TranscribeeApp",
            dependencies: ["TranscribeeCore"]
        ),
        .executableTarget(
            name: "TranscribeeCoreTests",
            dependencies: ["TranscribeeCore"]
        )
    ]
)
