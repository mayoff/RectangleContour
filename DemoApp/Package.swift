// swift-tools-version:5.4

// If you use RectangleContour.xcworkspace, then both the RectangleContour package and the DemoApp Xcode project show up as top-level items. This dummy Package.swift file prevents Xcode's project navigator from redundantly showing the DemoApp folder as a child of the RectangleContour package folder.

import PackageDescription

let package = Package(
    name: "RectangleContour-DemoApp",
    products: [],
    dependencies: [],
    targets: []
)
