//
//  AcademicComponents.swift
//  TranscriptumModule
//
//  Core components for academic records: Terms, Programs, Courses, Sections.
//  These are primarily curriculum/catalog data, typically synced from SIS.
//

import Foundation
import AnigmaCore

// MARK: - Term Component

/// Represents an academic term (semester, quarter, session).
public struct TermComponent: Component, Sendable {
    public let termId: TermId
    public var name: String                    // "Spring 2025"
    public var code: String                    // "2025SP"
    public var termType: TermType
    public var academicYear: String            // "2024-2025"

    // Dates
    public var startDate: Date
    public var endDate: Date
    public var censusDate: Date?               // Official enrollment count date
    public var lastAddDate: Date?
    public var lastDropDate: Date?
    public var gradesDueDate: Date?

    // Status
    public var status: TermStatus
    public var isCurrentTerm: Bool

    public init(
        termId: TermId,
        name: String,
        code: String,
        termType: TermType,
        academicYear: String,
        startDate: Date,
        endDate: Date,
        censusDate: Date? = nil,
        lastAddDate: Date? = nil,
        lastDropDate: Date? = nil,
        gradesDueDate: Date? = nil,
        status: TermStatus = .scheduled,
        isCurrentTerm: Bool = false
    ) {
        self.termId = termId
        self.name = name
        self.code = code
        self.termType = termType
        self.academicYear = academicYear
        self.startDate = startDate
        self.endDate = endDate
        self.censusDate = censusDate
        self.lastAddDate = lastAddDate
        self.lastDropDate = lastDropDate
        self.gradesDueDate = gradesDueDate
        self.status = status
        self.isCurrentTerm = isCurrentTerm
    }
}

public enum TermType: String, Codable, Sendable, CaseIterable {
    case fall
    case spring
    case summer
    case winter
    case shortSession
    case fullYear
}

public enum TermStatus: String, Codable, Sendable, CaseIterable {
    case scheduled
    case registration
    case inProgress
    case grading
    case completed
    case archived
}

// MARK: - Program Component

/// Represents an academic program (degree, certificate, pathway).
public struct ProgramComponent: Component, Sendable {
    public let programId: ProgramId
    public var title: String                   // "Associate in Science: Computer Science"
    public var shortTitle: String              // "CS AS"
    public var programType: ProgramType
    public var awardType: AwardType

    // Organizational
    public var departmentId: String?
    public var schoolId: String?
    public var divisionId: String?

    // Requirements
    public var totalUnitsRequired: Double
    public var majorUnitsRequired: Double?
    public var geUnitsRequired: Double?
    public var electiveUnitsRequired: Double?
    public var minimumGPA: Double

    // Catalog
    public var catalogYear: String             // "2024-2025"
    public var effectiveDate: Date
    public var discontinuedDate: Date?
    public var description: String?
    public var learningOutcomes: [String]

    // Flags
    public var isActive: Bool
    public var acceptingApplications: Bool
    public var requiresAdmission: Bool
    public var cipCode: String?                // Classification of Instructional Programs

    public init(
        programId: ProgramId,
        title: String,
        shortTitle: String,
        programType: ProgramType,
        awardType: AwardType,
        departmentId: String? = nil,
        schoolId: String? = nil,
        divisionId: String? = nil,
        totalUnitsRequired: Double,
        majorUnitsRequired: Double? = nil,
        geUnitsRequired: Double? = nil,
        electiveUnitsRequired: Double? = nil,
        minimumGPA: Double = 2.0,
        catalogYear: String,
        effectiveDate: Date = Date(),
        discontinuedDate: Date? = nil,
        description: String? = nil,
        learningOutcomes: [String] = [],
        isActive: Bool = true,
        acceptingApplications: Bool = true,
        requiresAdmission: Bool = false,
        cipCode: String? = nil
    ) {
        self.programId = programId
        self.title = title
        self.shortTitle = shortTitle
        self.programType = programType
        self.awardType = awardType
        self.departmentId = departmentId
        self.schoolId = schoolId
        self.divisionId = divisionId
        self.totalUnitsRequired = totalUnitsRequired
        self.majorUnitsRequired = majorUnitsRequired
        self.geUnitsRequired = geUnitsRequired
        self.electiveUnitsRequired = electiveUnitsRequired
        self.minimumGPA = minimumGPA
        self.catalogYear = catalogYear
        self.effectiveDate = effectiveDate
        self.discontinuedDate = discontinuedDate
        self.description = description
        self.learningOutcomes = learningOutcomes
        self.isActive = isActive
        self.acceptingApplications = acceptingApplications
        self.requiresAdmission = requiresAdmission
        self.cipCode = cipCode
    }
}

public enum ProgramType: String, Codable, Sendable, CaseIterable {
    case degree
    case certificate
    case diploma
    case pathway
    case noncredit
    case apprenticeship
}

public enum AwardType: String, Codable, Sendable, CaseIterable {
    case associateArts           // AA
    case associateScience        // AS
    case associateArtsTransfer   // AA-T
    case associateScienceTransfer // AS-T
    case certificateAchievement
    case certificateAccomplishment
    case certificateCompletion
    case bachelorArts            // BA (if applicable)
    case bachelorScience         // BS (if applicable)
    case noncreditCertificate
    case other
}

// MARK: - Course Component

/// Represents a course in the catalog.
public struct CourseComponent: Component, Sendable {
    public let courseId: CourseId
    public var subject: String                 // "CS", "MATH", "ENGL"
    public var number: String                  // "101", "110A"
    public var title: String                   // "Introduction to Computer Science"
    public var shortTitle: String              // "Intro to CS"

    // Units and hours
    public var creditUnits: Double             // 3.0
    public var creditUnitsMin: Double?         // For variable unit courses
    public var creditUnitsMax: Double?
    public var lectureHours: Double?
    public var labHours: Double?
    public var clinicalHours: Double?
    public var fieldworkHours: Double?

    // Classification
    public var courseType: CourseType
    public var gradingMode: GradingMode
    public var repeatableForCredit: Bool
    public var maxRepeatableUnits: Double?

    // Prerequisites and requirements
    public var prerequisites: [PrerequisiteRequirement]
    public var corequisites: [String]          // CourseIds
    public var advisories: [String]

    // Catalog
    public var catalogYear: String
    public var description: String?
    public var studentLearningOutcomes: [String]
    public var effectiveDate: Date
    public var discontinuedDate: Date?

    // Articulation and transfer
    public var transferable: TransferStatus
    public var csuGEArea: String?
    public var igecArea: String?
    public var ucTransferable: Bool
    public var csuTransferable: Bool
    public var cID: String?                    // Course Identification Number

    // Department
    public var departmentId: String?
    public var isActive: Bool

    public init(
        courseId: CourseId,
        subject: String,
        number: String,
        title: String,
        shortTitle: String,
        creditUnits: Double,
        creditUnitsMin: Double? = nil,
        creditUnitsMax: Double? = nil,
        lectureHours: Double? = nil,
        labHours: Double? = nil,
        clinicalHours: Double? = nil,
        fieldworkHours: Double? = nil,
        courseType: CourseType = .credit,
        gradingMode: GradingMode = .standard,
        repeatableForCredit: Bool = false,
        maxRepeatableUnits: Double? = nil,
        prerequisites: [PrerequisiteRequirement] = [],
        corequisites: [String] = [],
        advisories: [String] = [],
        catalogYear: String,
        description: String? = nil,
        studentLearningOutcomes: [String] = [],
        effectiveDate: Date = Date(),
        discontinuedDate: Date? = nil,
        transferable: TransferStatus = .notTransferable,
        csuGEArea: String? = nil,
        igecArea: String? = nil,
        ucTransferable: Bool = false,
        csuTransferable: Bool = false,
        cID: String? = nil,
        departmentId: String? = nil,
        isActive: Bool = true
    ) {
        self.courseId = courseId
        self.subject = subject
        self.number = number
        self.title = title
        self.shortTitle = shortTitle
        self.creditUnits = creditUnits
        self.creditUnitsMin = creditUnitsMin
        self.creditUnitsMax = creditUnitsMax
        self.lectureHours = lectureHours
        self.labHours = labHours
        self.clinicalHours = clinicalHours
        self.fieldworkHours = fieldworkHours
        self.courseType = courseType
        self.gradingMode = gradingMode
        self.repeatableForCredit = repeatableForCredit
        self.maxRepeatableUnits = maxRepeatableUnits
        self.prerequisites = prerequisites
        self.corequisites = corequisites
        self.advisories = advisories
        self.catalogYear = catalogYear
        self.description = description
        self.studentLearningOutcomes = studentLearningOutcomes
        self.effectiveDate = effectiveDate
        self.discontinuedDate = discontinuedDate
        self.transferable = transferable
        self.csuGEArea = csuGEArea
        self.igecArea = igecArea
        self.ucTransferable = ucTransferable
        self.csuTransferable = csuTransferable
        self.cID = cID
        self.departmentId = departmentId
        self.isActive = isActive
    }

    /// Full course designation (e.g., "CS 101")
    public var designation: String {
        "\(subject) \(number)"
    }
}

public enum CourseType: String, Codable, Sendable, CaseIterable {
    case credit
    case noncredit
    case developmental
    case honors
    case serviceLearnin
    case workExperience
    case independent
}

public enum GradingMode: String, Codable, Sendable, CaseIterable {
    case standard          // A-F with +/-
    case passNoPass        // P/NP only
    case optional          // Student choice
    case inProgress        // IP for multi-term
    case satisfactory      // S/U
}

public enum TransferStatus: String, Codable, Sendable, CaseIterable {
    case ucAndCSU
    case csuOnly
    case notTransferable
}

/// Prerequisite or corequisite requirement.
public struct PrerequisiteRequirement: Codable, Sendable {
    public var courseId: String?
    public var minimumGrade: String?           // "C" or better
    public var placementLevel: String?
    public var skillRequirement: String?
    public var isRequired: Bool                // true = prerequisite, false = recommended
    public var concurrentOk: Bool              // Can be taken concurrently

    public init(
        courseId: String? = nil,
        minimumGrade: String? = nil,
        placementLevel: String? = nil,
        skillRequirement: String? = nil,
        isRequired: Bool = true,
        concurrentOk: Bool = false
    ) {
        self.courseId = courseId
        self.minimumGrade = minimumGrade
        self.placementLevel = placementLevel
        self.skillRequirement = skillRequirement
        self.isRequired = isRequired
        self.concurrentOk = concurrentOk
    }
}

// MARK: - Course Section Component

/// Represents a specific offering of a course in a term.
public struct CourseSectionComponent: Component, Sendable {
    public let sectionId: SectionId
    public var courseId: CourseId
    public var termId: TermId
    public var sectionNumber: String           // "001", "W01" (online)

    // Capacity
    public var enrollmentCapacity: Int
    public var enrolledCount: Int
    public var waitlistCapacity: Int
    public var waitlistedCount: Int

    // Instructor
    public var primaryInstructorId: String?
    public var additionalInstructorIds: [String]

    // Schedule
    public var meetings: [SectionMeeting]
    public var instructionMode: InstructionMode
    public var sessionCode: String?            // For special sessions within term

    // Dates (may differ from term dates)
    public var startDate: Date?
    public var endDate: Date?

    // Status
    public var status: SectionStatus
    public var isOpen: Bool
    public var specialFees: Double?
    public var notes: String?

    // LMS
    public var lmsCourseId: String?            // Canvas course ID
    public var lmsCourseUrl: URL?

    public init(
        sectionId: SectionId,
        courseId: CourseId,
        termId: TermId,
        sectionNumber: String,
        enrollmentCapacity: Int,
        enrolledCount: Int = 0,
        waitlistCapacity: Int = 0,
        waitlistedCount: Int = 0,
        primaryInstructorId: String? = nil,
        additionalInstructorIds: [String] = [],
        meetings: [SectionMeeting] = [],
        instructionMode: InstructionMode = .inPerson,
        sessionCode: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        status: SectionStatus = .scheduled,
        isOpen: Bool = true,
        specialFees: Double? = nil,
        notes: String? = nil,
        lmsCourseId: String? = nil,
        lmsCourseUrl: URL? = nil
    ) {
        self.sectionId = sectionId
        self.courseId = courseId
        self.termId = termId
        self.sectionNumber = sectionNumber
        self.enrollmentCapacity = enrollmentCapacity
        self.enrolledCount = enrolledCount
        self.waitlistCapacity = waitlistCapacity
        self.waitlistedCount = waitlistedCount
        self.primaryInstructorId = primaryInstructorId
        self.additionalInstructorIds = additionalInstructorIds
        self.meetings = meetings
        self.instructionMode = instructionMode
        self.sessionCode = sessionCode
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.isOpen = isOpen
        self.specialFees = specialFees
        self.notes = notes
        self.lmsCourseId = lmsCourseId
        self.lmsCourseUrl = lmsCourseUrl
    }

    /// Available seats.
    public var availableSeats: Int {
        max(0, enrollmentCapacity - enrolledCount)
    }

    /// Whether section is full.
    public var isFull: Bool {
        enrolledCount >= enrollmentCapacity
    }
}

/// Meeting time for a section.
public struct SectionMeeting: Codable, Sendable {
    public var days: Set<Weekday>
    public var startTime: String               // "09:00" (24h)
    public var endTime: String                 // "10:15"
    public var buildingCode: String?
    public var roomNumber: String?
    public var campusId: String?
    public var meetingType: MeetingType

    public init(
        days: Set<Weekday>,
        startTime: String,
        endTime: String,
        buildingCode: String? = nil,
        roomNumber: String? = nil,
        campusId: String? = nil,
        meetingType: MeetingType = .lecture
    ) {
        self.days = days
        self.startTime = startTime
        self.endTime = endTime
        self.buildingCode = buildingCode
        self.roomNumber = roomNumber
        self.campusId = campusId
        self.meetingType = meetingType
    }

    public var location: String? {
        guard let building = buildingCode, let room = roomNumber else { return nil }
        return "\(building) \(room)"
    }
}

public enum Weekday: String, Codable, Sendable, CaseIterable {
    case monday = "M"
    case tuesday = "T"
    case wednesday = "W"
    case thursday = "R"
    case friday = "F"
    case saturday = "S"
    case sunday = "U"
}

public enum MeetingType: String, Codable, Sendable, CaseIterable {
    case lecture
    case lab
    case discussion
    case seminar
    case fieldwork
    case clinical
    case online
    case hybrid
}

public enum InstructionMode: String, Codable, Sendable, CaseIterable {
    case inPerson
    case online
    case hybrid
    case hyflex
    case correspondence
}

public enum SectionStatus: String, Codable, Sendable, CaseIterable {
    case scheduled
    case open
    case closed
    case cancelled
    case completed
}
