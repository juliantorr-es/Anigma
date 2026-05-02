// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreUtilities",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "CoreUtilities",
            targets: ["CoreUtilities"]),
        .library(
            name: "CapsuleRegistry",
            targets: ["CapsuleRegistry"]),
        .library(
            name: "ServiceDiscovery", 
            targets: ["ServiceDiscovery"]),
        .library(
            name: "QueueManager",
            targets: ["QueueManager"]),
        .library(
            name: "ConfigManager",
            targets: ["ConfigManager"]),
        .library(
            name: "LoggerCapsule",
            targets: ["LoggerCapsule"]),
        .library(
            name: "MetricsCollectorCapsule",
            targets: ["MetricsCollectorCapsule"]),
        .library(
            name: "EventAggregatorCapsule",
            targets: ["EventAggregatorCapsule"]),
        .library(
            name: "HealthCheckCapsule",
            targets: ["HealthCheckCapsule"]),
    ],
    dependencies: [
        .package(path: "../CapsuleCore"),
        .package(path: "../TelemetryCore"),
    ],
    targets: [
        .target(
            name: "CoreUtilities",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
                "CapsuleRegistry",
                "ServiceDiscovery",
                "QueueManager",
                "ConfigManager",
                "LoggerCapsule",
                "MetricsCollectorCapsule",
                "EventAggregatorCapsule",
                "HealthCheckCapsule",
            ]),
        .target(
            name: "CapsuleRegistry",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
            ]),
        .target(
            name: "ServiceDiscovery",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
                "CapsuleRegistry",
            ]),
        .target(
            name: "QueueManager",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
            ]),
        .target(
            name: "ConfigManager",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
            ]),
        .target(
            name: "LoggerCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
            ]),
        .target(
            name: "MetricsCollectorCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
            ]),
        .target(
            name: "EventAggregatorCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
                "QueueManager",
            ]),
        .target(
            name: "HealthCheckCapsule",
            dependencies: [
                "CapsuleCore",
                "TelemetryCore",
                "CapsuleRegistry",
            ]),
        .testTarget(
            name: "CoreUtilitiesTests",
            dependencies: [
                "CoreUtilities",
                "CapsuleCore",
                "TelemetryCore",
                "CapsuleRegistry",
                "ServiceDiscovery",
                "QueueManager",
                "ConfigManager",
                "LoggerCapsule",
                "MetricsCollectorCapsule",
                "EventAggregatorCapsule",
                "HealthCheckCapsule",
            ]),
    ]
)