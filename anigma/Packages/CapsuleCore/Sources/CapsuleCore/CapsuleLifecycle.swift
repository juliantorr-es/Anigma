// CapsuleLifecycle.swift
// CapsuleCore - Lifecycle protocol for capsules

public protocol CapsuleLifecycle: Sendable {
    /// Prepare the capsule for use (allocate resources, connections, etc)
    func activate() async throws

    /// Cleanup the capsule (free resources, close connections)
    func deactivate() async
}
