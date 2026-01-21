import Foundation
import AnigmaCore
import AnigmaSystemSpine

public struct EducationCourse: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let code: String
    public let term: String
    public let source: UUID
    public let externalId: String

    public init(id: UUID = UUID(), name: String, code: String, term: String, source: UUID, externalId: String) {
        self.id = id
        self.name = name
        self.code = code
        self.term = term
        self.source = source
        self.externalId = externalId
    }
}

public struct EducationAssignment: Identifiable, Codable, Sendable {
    public let id: UUID
    public let courseId: UUID
    public let title: String
    public let description: String?
    public let dueDate: Date?
    public let pointsPossible: Double?
    public let externalId: String

    public init(id: UUID = UUID(), courseId: UUID, title: String, description: String?, dueDate: Date?, pointsPossible: Double?, externalId: String) {
        self.id = id
        self.courseId = courseId
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.pointsPossible = pointsPossible
        self.externalId = externalId
    }
}

public struct EducationSubmission: Identifiable, Codable, Sendable {
    public let id: UUID
    public let assignmentId: UUID
    public let studentId: String
    public let submittedAt: Date
    public let status: SubmissionStatus
    public let grade: Double?
    public let externalId: String

    public enum SubmissionStatus: String, Codable, Sendable {
        case submitted
        case graded
        case returned
        case late
        case missing
    }

    public init(id: UUID = UUID(), assignmentId: UUID, studentId: String, submittedAt: Date, status: SubmissionStatus, grade: Double?, externalId: String) {
        self.id = id
        self.assignmentId = assignmentId
        self.studentId = studentId
        self.submittedAt = submittedAt
        self.status = status
        self.grade = grade
        self.externalId = externalId
    }
}

public struct EducationRosterMember: Identifiable, Codable, Sendable {
    public let id: UUID
    public let courseId: UUID
    public let userId: String
    public let role: EducationRole
    public let name: String
    public let email: String

    public enum EducationRole: String, Codable, Sendable {
        case student
        case teacher
        case ta
        case observer
        case admin
    }

    public init(id: UUID = UUID(), courseId: UUID, userId: String, role: EducationRole, name: String, email: String) {
        self.id = id
        self.courseId = courseId
        self.userId = userId
        self.role = role
        self.name = name
        self.email = email
    }
}
