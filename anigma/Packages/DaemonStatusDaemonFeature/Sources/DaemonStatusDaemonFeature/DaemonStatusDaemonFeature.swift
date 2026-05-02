import Foundation
import DaemonFeatureContracts

public struct DaemonStatusDaemonFeature: DaemonFeatureRegistrar {
    public static var featureID: FeatureID { "daemon-status" }

    public static var dependencies: [FeatureID] { [] }

    public static func register(into registry: inout DaemonFeatureRegistry) throws {
        let metadata = CapabilityMetadata(
            description: "Reports kernel registration and daemon wiring status.",
            requirements: []
        )
        registry.registerCapability(capabilityID: "daemon-status", metadata: metadata)
        registry.registerRoute(path: "/daemon/kernel-status", method: "GET") { _ in
            let payload = [
                "feature_id": featureID,
                "status": "ok"
            ]
            let body = try JSONEncoder().encode(payload)
            return RouteResponse(statusCode: 200, body: body)
        }
    }
}
