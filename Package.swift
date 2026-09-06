// swift-tools-version:5.10

import PackageDescription

let package = Package(
    name: "RectangleContour",
    platforms: [
      .iOS(.v14),
      .macCatalyst(.v14),
      .macOS(.v11),
      .tvOS(.v14),
      .visionOS(.v1),
      .watchOS(.v7),
    ],
    products: [
        // This is the library on which your own targets should depend.
        .library(
            name: "RectangleContour",
            targets: [
                "RectangleContour"
            ]),

        // This library contains the code for the Mac demo app. Your targets should not depend on it.
        .library(
            name: "MacDemoAppLibrary",
            targets: [
                "MacDemoAppModule",
                "RectangleContour",
            ]),

        // This library contains the code for the iPhone demo app. Your targets should not depend on it.
        .library(
            name: "PhoneDemoAppLibrary",
            targets: [
                "PhoneDemoAppModule",
                "RectangleContour",
            ])
    ],

    dependencies: [
    ],

    targets: [
        .target(
            name: "RectangleContour",
            dependencies: []),
        .testTarget(
            name: "RectangleContourTests",
            dependencies: ["RectangleContour"]),
        .target(
            name: "MacDemoAppModule",
            dependencies: ["RectangleContour"]),
        .target(
            name: "PhoneDemoAppModule",
            dependencies: ["RectangleContour"]),
    ]
)
