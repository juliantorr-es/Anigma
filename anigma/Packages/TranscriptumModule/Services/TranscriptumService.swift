//
//  TranscriptumService.swift
//  TranscriptumModule
//
//  High-level service for academic records operations.
//  Provides governed, audited access to all academic data.
//

import Foundation
import AnigmaCore
import AnigmaSystemSpine
import AnigmaPrimitives

// MARK: - Transcriptum Service

/// Service for managing academic records with full governance and audit.
public actor TranscriptumService {
    public nonisolated static let preferredLane: HardwareLane = TranscriptumModule.preferredLane

    private let world: SecuredWorld
    private let syncManager: AnigmaSystemSpine.SyncManager
    private let principal: AccessPrincipal

    public init(
        world: SecuredWorld,
        syncManager: AnigmaSystemSpine.SyncManager,
        principal: AccessPrincipal
    ) {
        self.world = world
        self.syncManager = syncManager
        self.principal = principal
    }

    // MARK: - Term Operations

    /// Gets the current academic term.
    public func getCurrentTerm() async throws -> (EntityId, TermComponent)? {
        let terms = try await world.query(TermComponent.self, as: principal)
        return terms.first { $0.1.isCurrentTerm }
    }

    /// Gets a term by its ID.
    public func getTerm(termId: TermId) async throws -> (EntityId, TermComponent)? {
        let terms = try await world.query(TermComponent.self, as: principal)
        return terms.first { $0.1.termId == termId }
    }

    /// Gets all terms for an academic year.
    public func getTerms(academicYear: String) async throws -> [(EntityId, TermComponent)] {
        let terms = try await world.query(TermComponent.self, as: principal)
        return terms.filter { $0.1.academicYear == academicYear }
    }

    // MARK: - Program Operations

    /// Gets a program by ID.
    public func getProgram(programId: ProgramId) async throws -> (EntityId, ProgramComponent)? {
        let programs = try await world.query(ProgramComponent.self, as: principal)
        return programs.first { $0.1.programId == programId }
    }

    /// Gets all active programs.
    public func getActivePrograms() async throws -> [(EntityId, ProgramComponent)] {
        let programs = try await world.query(ProgramComponent.self, as: principal)
        return programs.filter { $0.1.isActive }
    }

    /// Gets programs by department.
    public func getPrograms(departmentId: String) async throws -> [(EntityId, ProgramComponent)] {
        let programs = try await world.query(ProgramComponent.self, as: principal)
        return programs.filter { $0.1.departmentId == departmentId && $0.1.isActive }
    }

    // MARK: - Course Operations

    /// Gets a course by ID.
    public func getCourse(courseId: CourseId) async throws -> (EntityId, CourseComponent)? {
        let courses = try await world.query(CourseComponent.self, as: principal)
        return courses.first { $0.1.courseId == courseId }
    }

    /// Gets courses by subject.
    public func getCourses(subject: String) async throws -> [(EntityId, CourseComponent)] {
        let courses = try await world.query(CourseComponent.self, as: principal)
        return courses.filter { $0.1.subject == subject && $0.1.isActive }
    }

    /// Searches courses by title or description.
    public func searchCourses(query: String) async throws -> [(EntityId, CourseComponent)] {
        let lowercasedQuery = query.lowercased()
        let courses = try await world.query(CourseComponent.self, as: principal)
        return courses.filter { course in
            course.1.title.lowercased().contains(lowercasedQuery) ||
            course.1.shortTitle.lowercased().contains(lowercasedQuery) ||
            course.1.description?.lowercased().contains(lowercasedQuery) == true
        }
    }

    // MARK: - Section Operations

    /// Gets sections for a course in a term.
    public func getSections(courseId: CourseId, termId: TermId) async throws -> [(EntityId, CourseSectionComponent)] {
        let sections = try await world.query(CourseSectionComponent.self, as: principal)
        return sections.filter { $0.1.courseId == courseId && $0.1.termId == termId }
    }

    /// Gets sections taught by an instructor.
    public func getSections(instructorId: String, termId: TermId) async throws -> [(EntityId, CourseSectionComponent)] {
        let sections = try await world.query(CourseSectionComponent.self, as: principal)
        return sections.filter { section in
            section.1.termId == termId &&
            (section.1.primaryInstructorId == instructorId ||
             section.1.additionalInstructorIds.contains(instructorId))
        }
    }

    /// Gets open sections with available seats.
    public func getOpenSections(termId: TermId) async throws -> [(EntityId, CourseSectionComponent)] {
        let sections = try await world.query(CourseSectionComponent.self, as: principal)
        return sections.filter { $0.1.termId == termId && $0.1.isOpen && !$0.1.isFull }
    }

    // MARK: - Student Record Operations

    /// Gets a student's academic profile.
    public func getStudentProfile(studentId: String) async throws -> (EntityId, StudentAcademicProfileComponent)? {
        let profiles = try await world.query(StudentAcademicProfileComponent.self, as: principal)
        return profiles.first { $0.1.studentId == studentId }
    }

    /// Gets a student's enrollments for a term.
    public func getEnrollments(
        studentRecordId: StudentRecordId,
        termId: TermId
    ) async throws -> [(EntityId, EnrollmentComponent)] {
        let enrollments = try await world.query(EnrollmentComponent.self, as: principal)
        return enrollments.filter {
            $0.1.studentRecordId == studentRecordId && $0.1.termId == termId
        }
    }

    /// Gets a student's grade history.
    public func getGradeHistory(studentRecordId: StudentRecordId) async throws -> [(EntityId, GradeRecordComponent)] {
        let grades = try await world.query(GradeRecordComponent.self, as: principal)
        return grades
            .filter { $0.1.studentRecordId == studentRecordId }
            .sorted { $0.1.submittedAt > $1.1.submittedAt }
    }

    /// Gets a student's academic standing history.
    public func getStandingHistory(studentRecordId: StudentRecordId) async throws -> [(EntityId, AcademicStandingComponent)] {
        let standings = try await world.query(AcademicStandingComponent.self, as: principal)
        return standings
            .filter { $0.1.studentRecordId == studentRecordId }
            .sorted { $0.1.effectiveDate > $1.1.effectiveDate }
    }

    /// Gets a student's awarded degrees/certificates.
    public func getDegreeAwards(studentRecordId: StudentRecordId) async throws -> [(EntityId, DegreeAwardComponent)] {
        let awards = try await world.query(DegreeAwardComponent.self, as: principal)
        return awards.filter { $0.1.studentRecordId == studentRecordId }
    }

    // MARK: - Enrollment Management

    /// Enrolls a student in a section (creates enrollment record).
    public func enrollStudent(
        studentRecordId: StudentRecordId,
        sectionId: SectionId,
        termId: TermId,
        units: Double,
        gradingBasis: GradingBasis = .letter
    ) async throws -> EntityId {
        // Verify section exists and has capacity
        let sections = try await world.query(CourseSectionComponent.self, as: principal)
        guard let (sectionEntity, section) = sections.first(where: { $0.1.sectionId == sectionId }) else {
            throw TranscriptumError.sectionNotFound(sectionId.value)
        }

        guard section.isOpen else {
            throw TranscriptumError.sectionClosed(sectionId.value)
        }

        guard !section.isFull else {
            throw TranscriptumError.sectionFull(sectionId.value)
        }

        // Create enrollment
        let enrollment = EnrollmentComponent(
            studentRecordId: studentRecordId,
            sectionId: sectionId,
            termId: termId,
            status: .enrolled,
            gradingBasis: gradingBasis,
            unitsAttempted: units,
            createdBy: principal.id
        )

        let enrollmentEntity = try await world.createEntity(as: principal)
        try await world.addComponent(enrollmentEntity, enrollment, as: principal)

        // Update section enrollment count
        var updatedSection = section
        updatedSection.enrolledCount += 1
        try await world.addComponent(sectionEntity, updatedSection, as: principal)

        return enrollmentEntity
    }

    /// Drops a student from a section.
    public func dropStudent(
        enrollmentId: EnrollmentId,
        reason: WithdrawalReason = .studentInitiated
    ) async throws {
        let enrollments = try await world.query(EnrollmentComponent.self, as: principal)
        guard let (entity, enrollment) = enrollments.first(where: { $0.1.enrollmentId == enrollmentId }) else {
            throw TranscriptumError.enrollmentNotFound(enrollmentId.value.uuidString)
        }

        var updated = enrollment
        updated.status = .dropped
        updated.withdrawalDate = Date()
        updated.withdrawalReason = reason
        updated.lastStatusChangeDate = Date()
        updated.modifiedBy = principal.id
        updated.modifiedAt = Date()

        try await world.addComponent(entity, updated, as: principal)

        // Update section enrollment count
        let sections = try await world.query(CourseSectionComponent.self, as: principal)
        if let (sectionEntity, section) = sections.first(where: { $0.1.sectionId == enrollment.sectionId }) {
            var updatedSection = section
            updatedSection.enrolledCount = max(0, updatedSection.enrolledCount - 1)
            try await world.addComponent(sectionEntity, updatedSection, as: principal)
        }
    }

    // MARK: - Grade Management

    /// Submits a grade for an enrollment.
    public func submitGrade(
        enrollmentId: EnrollmentId,
        grade: String,
        gradePoints: Double?,
        unitsEarned: Double
    ) async throws -> EntityId {
        let enrollments = try await world.query(EnrollmentComponent.self, as: principal)
        guard let (enrollmentEntity, enrollment) = enrollments.first(where: { $0.1.enrollmentId == enrollmentId }) else {
            throw TranscriptumError.enrollmentNotFound(enrollmentId.value.uuidString)
        }

        // Get course ID from section
        let sections = try await world.query(CourseSectionComponent.self, as: principal)
        guard let (_, section) = sections.first(where: { $0.1.sectionId == enrollment.sectionId }) else {
            throw TranscriptumError.sectionNotFound(enrollment.sectionId.value)
        }

        let gradeRecord = GradeRecordComponent(
            enrollmentId: enrollmentId,
            studentRecordId: enrollment.studentRecordId,
            sectionId: enrollment.sectionId,
            termId: enrollment.termId,
            courseId: section.courseId,
            grade: grade,
            gradePoints: gradePoints,
            unitsEarned: unitsEarned,
            unitsAttempted: enrollment.unitsAttempted,
            qualityPoints: gradePoints.map { $0 * unitsEarned },
            submittedBy: principal.id
        )

        let gradeEntity = try await world.createEntity(as: principal)
        try await world.addComponent(gradeEntity, gradeRecord, as: principal)

        // Update enrollment status
        var updatedEnrollment = enrollment
        updatedEnrollment.status = EnrollmentRecordStatus.completed
        updatedEnrollment.modifiedBy = principal.id
        updatedEnrollment.modifiedAt = Date()
        try await world.addComponent(enrollmentEntity, updatedEnrollment, as: principal)

        return gradeEntity
    }

    // MARK: - Transcript Generation

    /// Generates an unofficial transcript for a student.
    public func generateTranscript(studentRecordId: StudentRecordId) async throws -> StudentTranscript {
        guard let (_, profile) = try await world.query(StudentAcademicProfileComponent.self, as: principal)
            .first(where: { $0.1.studentRecordId == studentRecordId }) else {
            throw TranscriptumError.studentNotFound(studentRecordId.value)
        }

        let grades = try await getGradeHistory(studentRecordId: studentRecordId)
        let awards = try await getDegreeAwards(studentRecordId: studentRecordId)

        // Group grades by term
        var termRecords: [TermId: [GradeRecordComponent]] = [:]
        for (_, grade) in grades {
            termRecords[grade.termId, default: []].append(grade)
        }

        // Build transcript entries
        var entries: [TranscriptTermEntry] = []
        for (termId, termGrades) in termRecords.sorted(by: { $0.key.value < $1.key.value }) {
            let termUnitsAttempted = termGrades.reduce(0.0) { $0 + $1.unitsAttempted }
            let termUnitsEarned = termGrades.reduce(0.0) { $0 + $1.unitsEarned }
            let termQualityPoints = termGrades.compactMap { $0.qualityPoints }.reduce(0.0, +)
            let gpaEligibleUnits = termGrades.filter { $0.isIncludedInGPA }.reduce(0.0) { $0 + $1.unitsAttempted }
            let termGPA = gpaEligibleUnits > 0 ? termQualityPoints / gpaEligibleUnits : nil

            let courseEntries = termGrades.map { grade in
                TranscriptCourseEntry(
                    courseId: grade.courseId.value,
                    grade: grade.grade,
                    units: grade.unitsEarned,
                    gradePoints: grade.gradePoints
                )
            }

            entries.append(TranscriptTermEntry(
                termId: termId.value,
                courses: courseEntries,
                termGPA: termGPA,
                termUnitsAttempted: termUnitsAttempted,
                termUnitsEarned: termUnitsEarned
            ))
        }

        return StudentTranscript(
            studentId: profile.studentId,
            studentRecordId: studentRecordId.value,
            generatedAt: Date(),
            terms: entries,
            cumulativeGPA: profile.cumulativeGPA,
            totalUnitsEarned: profile.cumulativeUnitsEarned,
            totalUnitsAttempted: profile.cumulativeUnitsAttempted,
            awards: awards.map { ($0.1.awardTitle, $0.1.conferralDate) }
        )
    }
}

// MARK: - Transcript Types

/// A generated student transcript.
public struct StudentTranscript: Sendable {
    public let studentId: String
    public let studentRecordId: String
    public let generatedAt: Date
    public let terms: [TranscriptTermEntry]
    public let cumulativeGPA: Double?
    public let totalUnitsEarned: Double
    public let totalUnitsAttempted: Double
    public let awards: [(title: String, date: Date)]

    public var isOfficial: Bool { false }  // Always unofficial from this service
}

/// A term entry on a transcript.
public struct TranscriptTermEntry: Sendable {
    public let termId: String
    public let courses: [TranscriptCourseEntry]
    public let termGPA: Double?
    public let termUnitsAttempted: Double
    public let termUnitsEarned: Double
}

/// A course entry on a transcript.
public struct TranscriptCourseEntry: Sendable {
    public let courseId: String
    public let grade: String
    public let units: Double
    public let gradePoints: Double?
}

// MARK: - Errors

public enum TranscriptumError: Error, LocalizedError {
    case studentNotFound(String)
    case sectionNotFound(String)
    case sectionClosed(String)
    case sectionFull(String)
    case enrollmentNotFound(String)
    case gradeNotFound(String)
    case programNotFound(String)
    case prerequisiteNotMet(String)
    case holdPreventsAction(String)
    case ferpaViolation(String)

    public var errorDescription: String? {
        switch self {
        case .studentNotFound(let id):
            return "Student not found: \(id)"
        case .sectionNotFound(let id):
            return "Section not found: \(id)"
        case .sectionClosed(let id):
            return "Section is closed: \(id)"
        case .sectionFull(let id):
            return "Section is full: \(id)"
        case .enrollmentNotFound(let id):
            return "Enrollment not found: \(id)"
        case .gradeNotFound(let id):
            return "Grade record not found: \(id)"
        case .programNotFound(let id):
            return "Program not found: \(id)"
        case .prerequisiteNotMet(let msg):
            return "Prerequisite not met: \(msg)"
        case .holdPreventsAction(let hold):
            return "Academic hold prevents action: \(hold)"
        case .ferpaViolation(let msg):
            return "FERPA violation: \(msg)"
        }
    }
}
