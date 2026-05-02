// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OSLogSwiftSyntaxConverter",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "oslog-converter", targets: ["OSLogConverter"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0")
    ],
    targets: [
        .executableTarget(
            name: "OSLogConverter",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ]
        )
    ]
)
