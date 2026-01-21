// Package.swift for CClipper2 system library
// This provides C bindings to Clipper2 polygon operations
// Note: This is just a reference - actual CClipper2 will be integrated 
// into the main Package.swift as a systemLibrary target

// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CClipper2",
    platforms: [
        .macOS(.v11),
        .iOS(.v14),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "CClipper2",
            type: .static(.automatic),
            targets: ["CClipper2"]
        )
    ],
    dependencies: [],
    targets: [
        .systemLibrary(
            name: "CClipper2",
            pkgConfig: "clipper2",
            providers: [
                .apt(["libclipper2-dev"]),
                .brew(["clipper2"])
            ]
        )
    ]
)