// swift-tools-version: 5.9
import PackageDescription

let strictConcurrencySettings: [SwiftSetting] = [
    .unsafeFlags(["-strict-concurrency=targeted"])
]

let package = Package(
    name: "ComplianceAuditModule",
    platforms: [
        .macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10)
    ],
    products: [
        .library(name: "ComplianceAuditModule", targets: ["ComplianceAuditModule"]),
    ],
    dependencies: [
        .package(path: "../DatabaseCore"),
        .package(path: "../GovernanceCore"),
        .package(path: "../ContractsCore"),
        .package(path: "../AnigmaPrimitives"),
    ],
    targets: [
        .target(
            name: "ComplianceAuditModule",
            dependencies: [
                "DatabaseCore",
                "GovernanceCore", 
                "ContractsCore",
                "AnigmaPrimitives"
            ],
            path: "Sources/ComplianceAuditModule",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "ComplianceAuditModuleTests",
            dependencies: [
                "ComplianceAuditModule",
                "DatabaseCore",
                "GovernanceCore",
                "ContractsCore", 
                "AnigmaPrimitives"
            ],
            path: "Tests/ComplianceAuditModuleTests",
            swiftSettings: strictConcurrencySettings
        ),
    ]
)