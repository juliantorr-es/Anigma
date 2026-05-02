import AnigmaPrimitives

import AnigmaPrimitives

//
//  StudentRecordComponents.swift
//  TranscriptumModule
//
//  FERPA-protected student academic record components.
//  These are highly sensitive and require strict access control.
//  All modifications are immutable transactions through governed workflows.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

// MARK: - Student Academic Profile

/// The core student academic profile linking to all their records.
/// This is the "hub" entity for a student's academic journey.
public struct StudentAcademicProfileComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "student_record", "pii"]

    public let studentRecordId: StudentRecordId
    public var contactEntityId: EntityId?      // Link to ConexusModule contact

    // Identifiers
    public var studentId: String               // Official student ID number
    public var externalIds: [String: String]   // SIS IDs, LMS IDs, etc.

    // Academic status
    public var enrollmentStatus: EnrollmentStatus
    public var studentType: StudentType
    public var residencyStatus: ResidencyStatus
    public var admitTermId: TermId?
    public var expectedGraduationTermId: TermId?

    // Programs
    public var declaredPrograms: [DeclaredProgram]
    public var academicLevel: AcademicLevel

    // Cumulative record
    public var cumulativeGPA: Double?
    public var cumulativeUnitsAttempted: Double
    public var cumulativeUnitsEarned: Double
    public var cumulativeUnitsTransferred: Double

    // Flags and holds
    public var academicHolds: [AcademicHold]
    public var flags: Set<StudentFlag>

    // DSPS / Accessibility
    public var dspsEligible: Bool
    public var hasActiveAccommodations: Bool
    public var accommodationCaseEntityId: EntityId?  // Link to ConexusModule case

    // Timestamps
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        studentRecordId: StudentRecordId,
        contactEntityId: EntityId? = nil,
        studentId: String,
        externalIds: [String: String] = [:],
        enrollmentStatus: EnrollmentStatus = .applicant,
        studentType: StudentType = .credit,
        residencyStatus: ResidencyStatus = .resident,
        admitTermId: TermId? = nil,
        expectedGraduationTermId: TermId? = nil,
        declaredPrograms: [DeclaredProgram] = [],
        academicLevel: AcademicLevel = .freshman,
        cumulativeGPA: Double? = nil,
        cumulativeUnitsAttempted: Double = 0,
        cumulativeUnitsEarned: Double = 0,
        cumulativeUnitsTransferred: Double = 0,
        academicHolds: [AcademicHold] = [],
        flags: Set<StudentFlag> = [],
        dspsEligible: Bool = false,
        hasActiveAccommodations: Bool = false,
        accommodationCaseEntityId: EntityId? = nil
    ) {
        self.studentRecordId = studentRecordId
        self.contactEntityId = contactEntityId
        self.studentId = studentId
        self.externalIds = externalIds
        self.enrollmentStatus = enrollmentStatus
        self.studentType = studentType
        self.residencyStatus = residencyStatus
        self.admitTermId = admitTermId
        self.expectedGraduationTermId = expectedGraduationTermId
        self.declaredPrograms = declaredPrograms
        self.academicLevel = academicLevel
        self.cumulativeGPA = cumulativeGPA
        self.cumulativeUnitsAttempted = cumulativeUnitsAttempted
        self.cumulativeUnitsEarned = cumulativeUnitsEarned
        self.cumulativeUnitsTransferred = cumulativeUnitsTransferred
        self.academicHolds = academicHolds
        self.flags = flags
        self.dspsEligible = dspsEligible
        self.hasActiveAccommodations = hasActiveAccommodations
        self.accommodationCaseEntityId = accommodationCaseEntityId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// A declared program for a student.
public struct DeclaredProgram: Codable, Sendable {
    public var programId: ProgramId
    public var status: ProgramDeclarationStatus
    public var declarationDate: Date
    public var catalogYear: String
    public var isPrimary: Bool
    public var advisorId: String?

    public init(
        programId: ProgramId,
        status: ProgramDeclarationStatus = .active,
        declarationDate: Date = Date(),
        catalogYear: String,
        isPrimary: Bool = true,
        advisorId: String? = nil
    ) {
        self.programId = programId
        self.status = status
        self.declarationDate = declarationDate
        self.catalogYear = catalogYear
        self.isPrimary = isPrimary
        self.advisorId = advisorId
    }
}

public enum ProgramDeclarationStatus: String, Codable, Sendable {
    case active
    case completed
    case withdrawn
    case suspended
}

public enum EnrollmentStatus: String, Codable, Sendable, CaseIterable {
    case applicant
    case admitted
    case enrolled
    case leave
    case withdrawn
    case dismissed
    case graduated
    case deceased
}

public enum StudentType: String, Codable, Sendable, CaseIterable {
    case credit
    case noncredit
    case concurrentEnrollment  // High school student
    case visiting
    case international
}

public enum ResidencyStatus: String, Codable, Sendable, CaseIterable {
    case resident
    case nonResident
    case ab540                 // California Dream Act
    case international
    case military
    case pending
}

public enum AcademicLevel: String, Codable, Sendable, CaseIterable {
    case freshman              // 0-29.9 units
    case sophomore             // 30-59.9 units
    case junior                // 60-89.9 units (if applicable)
    case senior                // 90+ units (if applicable)
    case graduate
    case noncredit
}

public enum StudentFlag: String, Codable, Sendable, Hashable {
    case firstGeneration
    case veteran
    case foster
    case calworks
    case eops
    case dsps
    case dreamer
    case internationalStudent
    case athlete
    case honors
    case probation
    case disqualified
}

/// An academic hold preventing registration or other actions.
public struct AcademicHold: Codable, Sendable {
    public var holdType: HoldType
    public var reason: String
    public var placedDate: Date
    public var placedBy: String
    public var expirationDate: Date?
    public var clearedDate: Date?
    public var clearedBy: String?

    public init(
        holdType: HoldType,
        reason: String,
        placedDate: Date = Date(),
        placedBy: String,
        expirationDate: Date? = nil,
        clearedDate: Date? = nil,
        clearedBy: String? = nil
    ) {
        self.holdType = holdType
        self.reason = reason
        self.placedDate = placedDate
        self.placedBy = placedBy
        self.expirationDate = expirationDate
        self.clearedDate = clearedDate
        self.clearedBy = clearedBy
    }

    public var isActive: Bool {
        clearedDate == nil && (expirationDate == nil || expirationDate! > Date())
    }
}

public enum HoldType: String, Codable, Sendable {
    case registration
    case financial
    case academic
    case disciplinary
    case transcript
    case graduation
    case admissions
    case immunization
    case library
    case parking
}

// MARK: - Enrollment Component

/// Represents a student's enrollment in a specific course section.
/// This is an immutable transaction record.
public struct EnrollmentComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "student_record"]

    public let enrollmentId: EnrollmentId
    public let studentRecordId: StudentRecordId
    public let sectionId: SectionId
    public let termId: TermId

    // Enrollment details
    public var status: EnrollmentRecordStatus
    public var enrollmentDate: Date
    public var enrollmentType: EnrollmentType
    public var gradingBasis: GradingBasis
    public var unitsAttempted: Double

    // Status changes
    public var lastStatusChangeDate: Date
    public var lastStatusChangeReason: String?
    public var withdrawalDate: Date?
    public var withdrawalReason: WithdrawalReason?

    // Repeat information
    public var isRepeat: Bool
    public var repeatCount: Int
    public var forgivesPreviousGrade: Bool

    // Accommodations
    public var hasAccommodations: Bool
    public var accommodationNotes: String?

    // Audit trail
    public var createdBy: String
    public var createdAt: Date
    public var modifiedBy: String?
    public var modifiedAt: Date?

    public init(
        enrollmentId: EnrollmentId = EnrollmentId(),
        studentRecordId: StudentRecordId,
        sectionId: SectionId,
        termId: TermId,
        status: EnrollmentRecordStatus = .enrolled,
        enrollmentDate: Date = Date(),
        enrollmentType: EnrollmentType = .standard,
        gradingBasis: GradingBasis = .letter,
        unitsAttempted: Double,
        lastStatusChangeDate: Date = Date(),
        lastStatusChangeReason: String? = nil,
        withdrawalDate: Date? = nil,
        withdrawalReason: WithdrawalReason? = nil,
        isRepeat: Bool = false,
        repeatCount: Int = 0,
        forgivesPreviousGrade: Bool = false,
        hasAccommodations: Bool = false,
        accommodationNotes: String? = nil,
        createdBy: String
    ) {
        self.enrollmentId = enrollmentId
        self.studentRecordId = studentRecordId
        self.sectionId = sectionId
        self.termId = termId
        self.status = status
        self.enrollmentDate = enrollmentDate
        self.enrollmentType = enrollmentType
        self.gradingBasis = gradingBasis
        self.unitsAttempted = unitsAttempted
        self.lastStatusChangeDate = lastStatusChangeDate
        self.lastStatusChangeReason = lastStatusChangeReason
        self.withdrawalDate = withdrawalDate
        self.withdrawalReason = withdrawalReason
        self.isRepeat = isRepeat
        self.repeatCount = repeatCount
        self.forgivesPreviousGrade = forgivesPreviousGrade
        self.hasAccommodations = hasAccommodations
        self.accommodationNotes = accommodationNotes
        self.createdBy = createdBy
        self.createdAt = Date()
    }
}

public enum EnrollmentRecordStatus: String, Codable, Sendable {
    case enrolled
    case waitlisted
    case dropped
    case withdrawn
    case completed
    case incomplete
    case cancelled
}

public enum EnrollmentType: String, Codable, Sendable {
    case standard
    case audit
    case creditByExam
    case concurrentEnrollment
    case crossEnrollment
    case extensionCourse
}

public enum GradingBasis: String, Codable, Sendable {
    case letter        // A-F
    case passNoPass    // P/NP
    case satisfactory  // S/U
    case inProgress    // IP (multi-term)
}

public enum WithdrawalReason: String, Codable, Sendable {
    case studentInitiated
    case administrativeWithdrawal
    case militaryWithdrawal
    case medicalWithdrawal
    case financialHold
    case noShow
    case disciplinary
    case excusedWithdrawal
}

// MARK: - Grade Record Component

/// An immutable grade record for a course enrollment.
/// Grades can only be changed through formal grade change workflows.
public struct GradeRecordComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "student_record", "grade"]

    public let gradeRecordId: UUID
    public let enrollmentId: EnrollmentId
    public let studentRecordId: StudentRecordId
    public let sectionId: SectionId
    public let termId: TermId
    public let courseId: CourseId

    // Grade information
    public var grade: String                   // "A", "B+", "P", "W", etc.
    public var gradePoints: Double?            // 4.0, 3.3, etc.
    public var unitsEarned: Double
    public var unitsAttempted: Double
    public var qualityPoints: Double?          // grade points × units

    // Grade metadata
    public var gradeType: GradeType
    public var isIncludedInGPA: Bool
    public var isReplacedByRepeat: Bool
    public var replacingGradeRecordId: UUID?

    // Submission info
    public var submittedBy: String             // Instructor ID
    public var submittedAt: Date
    public var approvedBy: String?             // For grade changes
    public var approvedAt: Date?

    // Audit trail
    public var previousGrades: [GradeChange]
    public var isOfficial: Bool
    public var postedToTranscriptAt: Date?

    public init(
        gradeRecordId: UUID = UUID(),
        enrollmentId: EnrollmentId,
        studentRecordId: StudentRecordId,
        sectionId: SectionId,
        termId: TermId,
        courseId: CourseId,
        grade: String,
        gradePoints: Double? = nil,
        unitsEarned: Double,
        unitsAttempted: Double,
        qualityPoints: Double? = nil,
        gradeType: GradeType = .final,
        isIncludedInGPA: Bool = true,
        isReplacedByRepeat: Bool = false,
        replacingGradeRecordId: UUID? = nil,
        submittedBy: String,
        submittedAt: Date = Date(),
        approvedBy: String? = nil,
        approvedAt: Date? = nil,
        previousGrades: [GradeChange] = [],
        isOfficial: Bool = true,
        postedToTranscriptAt: Date? = nil
    ) {
        self.gradeRecordId = gradeRecordId
        self.enrollmentId = enrollmentId
        self.studentRecordId = studentRecordId
        self.sectionId = sectionId
        self.termId = termId
        self.courseId = courseId
        self.grade = grade
        self.gradePoints = gradePoints
        self.unitsEarned = unitsEarned
        self.unitsAttempted = unitsAttempted
        self.qualityPoints = qualityPoints
        self.gradeType = gradeType
        self.isIncludedInGPA = isIncludedInGPA
        self.isReplacedByRepeat = isReplacedByRepeat
        self.replacingGradeRecordId = replacingGradeRecordId
        self.submittedBy = submittedBy
        self.submittedAt = submittedAt
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.previousGrades = previousGrades
        self.isOfficial = isOfficial
        self.postedToTranscriptAt = postedToTranscriptAt
    }
}

public enum GradeType: String, Codable, Sendable {
    case midterm
    case final
    case gradeChange
    case incomplete
    case inProgress
}

/// Record of a grade change.
public struct GradeChange: Codable, Sendable {
    public var previousGrade: String
    public var newGrade: String
    public var changeReason: String
    public var changedBy: String
    public var changedAt: Date
    public var approvedBy: String?
    public var approvedAt: Date?

    public init(
        previousGrade: String,
        newGrade: String,
        changeReason: String,
        changedBy: String,
        changedAt: Date = Date(),
        approvedBy: String? = nil,
        approvedAt: Date? = nil
    ) {
        self.previousGrade = previousGrade
        self.newGrade = newGrade
        self.changeReason = changeReason
        self.changedBy = changedBy
        self.changedAt = changedAt
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
    }
}

// MARK: - Academic Standing Component

/// Tracks a student's academic standing each term.
public struct AcademicStandingComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "student_record"]

    public let standingRecordId: UUID
    public let studentRecordId: StudentRecordId
    public let termId: TermId

    // Standing
    public var standing: StandingType
    public var previousStanding: StandingType?

    // Term statistics
    public var termGPA: Double?
    public var termUnitsAttempted: Double
    public var termUnitsEarned: Double
    public var cumulativeGPA: Double?
    public var cumulativeUnitsAttempted: Double
    public var cumulativeUnitsEarned: Double

    // Progress metrics
    public var completionRate: Double?         // Units earned / units attempted
    public var paceRate: Double?               // For financial aid SAP

    // Dates
    public var effectiveDate: Date
    public var reviewedBy: String?
    public var reviewedAt: Date?
    public var notes: String?

    public init(
        standingRecordId: UUID = UUID(),
        studentRecordId: StudentRecordId,
        termId: TermId,
        standing: StandingType,
        previousStanding: StandingType? = nil,
        termGPA: Double? = nil,
        termUnitsAttempted: Double = 0,
        termUnitsEarned: Double = 0,
        cumulativeGPA: Double? = nil,
        cumulativeUnitsAttempted: Double = 0,
        cumulativeUnitsEarned: Double = 0,
        completionRate: Double? = nil,
        paceRate: Double? = nil,
        effectiveDate: Date = Date(),
        reviewedBy: String? = nil,
        reviewedAt: Date? = nil,
        notes: String? = nil
    ) {
        self.standingRecordId = standingRecordId
        self.studentRecordId = studentRecordId
        self.termId = termId
        self.standing = standing
        self.previousStanding = previousStanding
        self.termGPA = termGPA
        self.termUnitsAttempted = termUnitsAttempted
        self.termUnitsEarned = termUnitsEarned
        self.cumulativeGPA = cumulativeGPA
        self.cumulativeUnitsAttempted = cumulativeUnitsAttempted
        self.cumulativeUnitsEarned = cumulativeUnitsEarned
        self.completionRate = completionRate
        self.paceRate = paceRate
        self.effectiveDate = effectiveDate
        self.reviewedBy = reviewedBy
        self.reviewedAt = reviewedAt
        self.notes = notes
    }
}

public enum StandingType: String, Codable, Sendable {
    case goodStanding
    case academicWarning
    case academicProbation
    case academicDismissal
    case reinstated
    case deansHonorList
    case presidentsHonorList
}

// MARK: - Degree Award Component

/// Records a degree, certificate, or other award conferred to a student.
public struct DegreeAwardComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "student_record", "credential"]

    public let awardId: UUID
    public let studentRecordId: StudentRecordId
    public let programId: ProgramId

    // Award details
    public var awardType: AwardType
    public var awardTitle: String              // Full title on diploma
    public var honors: HonorsDesignation?
    public var specializations: [String]

    // Conferral
    public var conferralDate: Date
    public var conferralTermId: TermId
    public var diplomaDate: Date?

    // Requirements
    public var finalGPA: Double
    public var totalUnitsEarned: Double
    public var requirementsMetDate: Date
    public var auditedBy: String?
    public var auditedAt: Date?

    // Status
    public var status: AwardStatus
    public var revokedDate: Date?
    public var revocationReason: String?

    public init(
        awardId: UUID = UUID(),
        studentRecordId: StudentRecordId,
        programId: ProgramId,
        awardType: AwardType,
        awardTitle: String,
        honors: HonorsDesignation? = nil,
        specializations: [String] = [],
        conferralDate: Date,
        conferralTermId: TermId,
        diplomaDate: Date? = nil,
        finalGPA: Double,
        totalUnitsEarned: Double,
        requirementsMetDate: Date,
        auditedBy: String? = nil,
        auditedAt: Date? = nil,
        status: AwardStatus = .conferred
    ) {
        self.awardId = awardId
        self.studentRecordId = studentRecordId
        self.programId = programId
        self.awardType = awardType
        self.awardTitle = awardTitle
        self.honors = honors
        self.specializations = specializations
        self.conferralDate = conferralDate
        self.conferralTermId = conferralTermId
        self.diplomaDate = diplomaDate
        self.finalGPA = finalGPA
        self.totalUnitsEarned = totalUnitsEarned
        self.requirementsMetDate = requirementsMetDate
        self.auditedBy = auditedBy
        self.auditedAt = auditedAt
        self.status = status
    }
}

public enum HonorsDesignation: String, Codable, Sendable {
    case honors              // 3.5+
    case highHonors          // 3.7+
    case highestHonors       // 3.9+
    case cumLaude            // With honor
    case magnaCumLaude       // With great honor
    case summaCumLaude       // With highest honor
}

public enum AwardStatus: String, Codable, Sendable {
    case pending
    case approved
    case conferred
    case revoked
}
