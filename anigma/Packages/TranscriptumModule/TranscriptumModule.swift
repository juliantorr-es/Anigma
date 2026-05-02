//
//  TranscriptumModule.swift
//  TranscriptumModule
//
//  Academic Records domain ("transcriptum" = Latin for "transcript, written copy").
//  Provides: Programs, Courses, Sections, Terms, Enrollments, Grades, Standing, Degrees.
//
//  Designed to be either:
//  - An overlay that mirrors external SIS data with annotations
//  - The system of record for academic data (full SIS replacement)
//
//  All academic records are:
//  - FERPA-compliant by design (restricted sensitivity, full audit trail)
//  - Immutable except through governed workflows
//  - Versioned and traceable
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

// MARK: - Module Definition

/// TranscriptumModule provides academic records management for institutions.
public enum TranscriptumModule {
    /// Module identifier.
    public static let moduleId = "Transcriptum"

    /// Closest existing lane for transcript workloads.
    /// Transcript generation is document-heavy, so it maps to the evidence lane.
    public static let preferredLane: HardwareLane = .evidence

    /// Initialize the module with a SecuredWorld.
    public static func initialize(with world: SecuredWorld) async {
        // Register all academic record components as restricted (FERPA)
        await world.registerComponentSensitivity(
            ProgramComponent.self,
            sensitivity: .internal,
            categories: ["academic", "curriculum"]
        )
        await world.registerComponentSensitivity(
            CourseComponent.self,
            sensitivity: .internal,
            categories: ["academic", "curriculum"]
        )
        await world.registerComponentSensitivity(
            CourseSectionComponent.self,
            sensitivity: .internal,
            categories: ["academic", "scheduling"]
        )
        await world.registerComponentSensitivity(
            TermComponent.self,
            sensitivity: .public,
            categories: ["academic", "calendar"]
        )
        await world.registerComponentSensitivity(
            EnrollmentComponent.self,
            sensitivity: .restricted,
            categories: ["academic", "student_record", "ferpa"]
        )
        await world.registerComponentSensitivity(
            GradeRecordComponent.self,
            sensitivity: .restricted,
            categories: ["academic", "student_record", "ferpa"]
        )
        await world.registerComponentSensitivity(
            AcademicStandingComponent.self,
            sensitivity: .restricted,
            categories: ["academic", "student_record", "ferpa"]
        )
        await world.registerComponentSensitivity(
            DegreeAwardComponent.self,
            sensitivity: .restricted,
            categories: ["academic", "student_record", "ferpa"]
        )
        await world.registerComponentSensitivity(
            StudentAcademicProfileComponent.self,
            sensitivity: .restricted,
            categories: ["academic", "student_record", "ferpa"]
        )
    }
}

// MARK: - Domain Identifiers

/// Unique identifier for academic terms.
public struct TermId: Hashable, Codable, Sendable {
    public let value: String  // e.g., "2025SP", "2024FA"

    public init(_ value: String) {
        self.value = value
    }
}

/// Unique identifier for academic programs.
public struct ProgramId: Hashable, Codable, Sendable {
    public let value: String  // e.g., "CS-AS", "MATH-AA"

    public init(_ value: String) {
        self.value = value
    }
}

/// Unique identifier for courses.
public struct CourseId: Hashable, Codable, Sendable {
    public let value: String  // e.g., "CS-101", "MATH-110"

    public init(_ value: String) {
        self.value = value
    }
}

/// Unique identifier for course sections.
public struct SectionId: Hashable, Codable, Sendable {
    public let value: String  // e.g., "CS-101-001-2025SP"

    public init(_ value: String) {
        self.value = value
    }
}

/// Unique identifier for enrollments.
public struct EnrollmentId: Hashable, Codable, Sendable {
    public let value: UUID

    public init(_ value: UUID = UUID()) {
        self.value = value
    }
}

/// Unique identifier for student academic records.
public struct StudentRecordId: Hashable, Codable, Sendable {
    public let value: String  // Typically student ID number

    public init(_ value: String) {
        self.value = value
    }
}

// MARK: - Database Integration

private actor TranscriptumDatabase {
    internal let dbActor: DatabaseAuthorityAdapter
    
    public init(dbActor: DatabaseAuthorityAdapter) {
        self.dbActor = dbActor
    }
    
    public func migrate() async throws {
        // Open the database connection
        try await dbActor.open()
        // No schema migrations yet
        // Future migrations will be added here
    }
}

// MARK: - CapabilityModule Conformance

extension TranscriptumModule: CapabilityModule {
    public static func register(runtime: PlatformRuntime) async throws {
        // Get database adapter for migration compatibility
        let databaseAuthority = await runtime.database
        let databaseAdapter = DatabaseAuthorityAdapter(databaseAuthority: databaseAuthority)
        let database = TranscriptumDatabase(dbActor: databaseAdapter)
        try await database.migrate()
        
        // TODO: Set up other authorities (evidence, artifact) if used
        
        await PlatformLogger.shared.info("TranscriptumModule registered with database adapter", category: "Runtime")
    }
}
