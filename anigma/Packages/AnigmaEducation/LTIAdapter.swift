import Foundation
import AnigmaSystemSpine

// MARK: - LTI 1.3 Adapter

public class LTIAdapter {
    private let jobId: String
    private let jobEngine: JobEngine

    public init(jobId: String, jobEngine: JobEngine) {
        self.jobId = jobId
        self.jobEngine = jobEngine
    }

    public func handleLaunch(payload: [String: Any]) async throws -> EducationCourse {
        // In a real implementation, we would validate the JWT signature here.
        // For now, we extract the context claim.

        guard let context = payload["https://purl.imsglobal.org/spec/lti/claim/context"] as? [String: Any],
              let id = context["id"] as? String,
              let label = context["label"] as? String,
              let title = context["title"] as? String else {
            throw EducationError.invalidLTIPayload
        }

        let course = EducationCourse(
            name: title,
            code: label,
            term: "Default Term", // Extract from custom claims if available
            source: UUID(), // Should be the integration ID
            externalId: id
        )

        // Enqueue a roster sync job
        let payloadData = try JSONSerialization.data(withJSONObject: ["courseId": course.externalId])
        let syncJob = SharedJob(
            type: .rosterSync,
            payload: payloadData,
            idempotencyKey: "roster_sync_\(course.externalId)",
            priority: .utility,
            sourceSurface: "education.lti"
        )
        try await jobEngine.enqueue(syncJob)

        return course
    }

    public func syncRoster(courseId: String) async throws -> [EducationRosterMember] {
        // Call NRPS endpoint
        // In a real implementation, we would use the Names and Role Provisioning Service
        return []
    }

    public func passbackGrade(submissionId: String, score: Double) async throws {
        // Call AGS endpoint
        // In a real implementation, we would use the Assignment and Grade Service
        let payloadData = try JSONSerialization.data(withJSONObject: ["submissionId": submissionId, "score": score])
        let job = SharedJob(
            type: .writeBack,
            payload: payloadData,
            idempotencyKey: "grade_passback_\(submissionId)",
            priority: .userInitiated,
            sourceSurface: "education.lti"
        )
        try await jobEngine.enqueue(job)
    }
}

public enum EducationError: Error {
    case invalidLTIPayload
    case networkError
}
