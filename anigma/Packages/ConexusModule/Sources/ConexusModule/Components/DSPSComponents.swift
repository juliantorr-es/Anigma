//
//  DSPSComponents.swift
//  ConexusModule
//
//  DSPS (Disabled Students Programs and Services) specific components.
//  These model accommodation cases, alt-media requests, and DSPS workflows.
//
//  These are highly sensitive (FERPA + ADA) and require strict governance.
//

import Foundation
import AnigmaCore
import AnigmaPrimitives

// MARK: - DSPS Identifiers

/// Unique identifier for DSPS cases.
public struct DSPSCaseId: Hashable, Codable, Sendable {
    public let value: UUID

    public init(_ value: UUID = UUID()) {
        self.value = value
    }
}

/// Unique identifier for alt-media requests.
public struct AltMediaRequestId: Hashable, Codable, Sendable {
    public let value: UUID

    public init(_ value: UUID = UUID()) {
        self.value = value
    }
}

/// Unique identifier for accommodation letters.
public struct AccommodationLetterId: Hashable, Codable, Sendable {
    public let value: UUID

    public init(_ value: UUID = UUID()) {
        self.value = value
    }
}

// MARK: - Student DSPS Profile

/// DSPS-specific extension of a student profile.
/// Links to the student's Conexus contact and Transcriptum academic profile.
public struct StudentDSPSProfileComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "ada", "disability", "pii"]

    public let dspsStudentId: UUID
    public var contactEntityId: EntityId?              // Link to ConexusModule contact
    public var academicProfileEntityId: EntityId?     // Link to TranscriptumModule profile
    public var studentId: String                       // Official student ID

    // Eligibility
    public var eligibilityStatus: DSPSEligibilityStatus
    public var eligibilityDeterminationDate: Date?
    public var eligibilityReviewDate: Date?           // Next review date
    public var primaryDisabilityCategory: DisabilityCategory?
    public var secondaryDisabilityCategories: [DisabilityCategory]

    // Documentation (references only, not content)
    public var documentationOnFile: Bool
    public var documentationExpirationDate: Date?
    public var documentationNotes: String?

    // Assigned staff
    public var primaryCounselorId: String?
    public var altMediaSpecialistId: String?
    public var assignedCaseManagerId: String?

    // Preferences
    public var preferredAltMediaFormats: [AltMediaFormat]
    public var preferredCommunicationMethod: CommunicationMethod
    public var requiresSignLanguageInterpreter: Bool
    public var requiresCaptioning: Bool
    public var requiresNoteServices: Bool

    // Contact preferences
    public var preferredContactTime: String?
    public var emergencyContactId: EntityId?

    // Status
    public var isActive: Bool
    public var lastContactDate: Date?
    public var nextAppointmentDate: Date?
    public var notes: String?                          // General case notes

    // Audit
    public var createdAt: Date
    public var updatedAt: Date
    public var createdBy: String

    public init(
        dspsStudentId: UUID = UUID(),
        contactEntityId: EntityId? = nil,
        academicProfileEntityId: EntityId? = nil,
        studentId: String,
        eligibilityStatus: DSPSEligibilityStatus = .pending,
        eligibilityDeterminationDate: Date? = nil,
        eligibilityReviewDate: Date? = nil,
        primaryDisabilityCategory: DisabilityCategory? = nil,
        secondaryDisabilityCategories: [DisabilityCategory] = [],
        documentationOnFile: Bool = false,
        documentationExpirationDate: Date? = nil,
        documentationNotes: String? = nil,
        primaryCounselorId: String? = nil,
        altMediaSpecialistId: String? = nil,
        assignedCaseManagerId: String? = nil,
        preferredAltMediaFormats: [AltMediaFormat] = [],
        preferredCommunicationMethod: CommunicationMethod = .email,
        requiresSignLanguageInterpreter: Bool = false,
        requiresCaptioning: Bool = false,
        requiresNoteServices: Bool = false,
        preferredContactTime: String? = nil,
        emergencyContactId: EntityId? = nil,
        isActive: Bool = true,
        lastContactDate: Date? = nil,
        nextAppointmentDate: Date? = nil,
        notes: String? = nil,
        createdBy: String
    ) {
        self.dspsStudentId = dspsStudentId
        self.contactEntityId = contactEntityId
        self.academicProfileEntityId = academicProfileEntityId
        self.studentId = studentId
        self.eligibilityStatus = eligibilityStatus
        self.eligibilityDeterminationDate = eligibilityDeterminationDate
        self.eligibilityReviewDate = eligibilityReviewDate
        self.primaryDisabilityCategory = primaryDisabilityCategory
        self.secondaryDisabilityCategories = secondaryDisabilityCategories
        self.documentationOnFile = documentationOnFile
        self.documentationExpirationDate = documentationExpirationDate
        self.documentationNotes = documentationNotes
        self.primaryCounselorId = primaryCounselorId
        self.altMediaSpecialistId = altMediaSpecialistId
        self.assignedCaseManagerId = assignedCaseManagerId
        self.preferredAltMediaFormats = preferredAltMediaFormats
        self.preferredCommunicationMethod = preferredCommunicationMethod
        self.requiresSignLanguageInterpreter = requiresSignLanguageInterpreter
        self.requiresCaptioning = requiresCaptioning
        self.requiresNoteServices = requiresNoteServices
        self.preferredContactTime = preferredContactTime
        self.emergencyContactId = emergencyContactId
        self.isActive = isActive
        self.lastContactDate = lastContactDate
        self.nextAppointmentDate = nextAppointmentDate
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.createdBy = createdBy
    }
}

public enum DSPSEligibilityStatus: String, Codable, Sendable {
    case pending
    case documentationRequested
    case underReview
    case eligible
    case conditionallyEligible
    case notEligible
    case appealing
    case inactive
    case graduated
}

public enum DisabilityCategory: String, Codable, Sendable, CaseIterable {
    // Primary categories per CCCCO/Section 504
    case visuallyImpaired           // Blind, low vision
    case hearingImpaired            // Deaf, hard of hearing
    case speechLanguage             // Speech/language impairment
    case physicalDisability         // Mobility, orthopedic
    case learningDisability         // Specific learning disability
    case intellectualDisability     // Intellectual/developmental
    case acquiredBrainInjury        // TBI, stroke
    case psychologicalDisability    // Mental health
    case autism                     // ASD
    case adhd                       // ADD/ADHD
    case other                      // Other health impairment
    case temporaryDisability        // Temporary condition
}

public enum AltMediaFormat: String, Codable, Sendable, CaseIterable {
    case epub                       // Accessible EPUB 3
    case taggedPDF                  // Properly tagged PDF
    case largePrint                 // Large print (18pt+)
    case braille                    // Braille (various grades)
    case audio                      // Audio/text-to-speech ready
    case tactileGraphics            // Tactile diagrams/images
    case plainText                  // Plain text
    case html                       // Accessible HTML
    case word                       // Microsoft Word
    case mathML                     // MathML for equations
    case daisy                      // DAISY format
    case kurzweil                   // Kurzweil 3000 format
}

public enum CommunicationMethod: String, Codable, Sendable {
    case email
    case phone
    case text
    case videophone                 // For deaf/HoH students
    case inPerson
    case mail
}

// MARK: - Accommodation Case Component

/// An accommodation case for a student for a specific term/period.
/// Contains the approved accommodations and their delivery status.
public struct AccommodationCaseComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "ada", "accommodation"]

    public let caseId: DSPSCaseId
    public var dspsStudentProfileEntityId: EntityId
    public var termId: String                          // Academic term this case covers

    // Case details
    public var caseType: AccommodationCaseType
    public var status: AccommodationCaseStatus
    public var priority: DSPSCasePriority

    // Approved accommodations for this term
    public var approvedAccommodations: [ApprovedAccommodation]

    // Courses for this term (linked to Transcriptum sections)
    public var enrolledSections: [EnrolledSectionInfo]

    // Letters
    public var accommodationLetterIds: [AccommodationLetterId]
    public var lettersGeneratedAt: Date?
    public var lettersDeliveredAt: Date?

    // Workflow tracking
    public var assignedToId: String?
    public var intakeMeetingDate: Date?
    public var intakeMeetingCompletedAt: Date?
    public var accommodationsApprovedAt: Date?
    public var approvedBy: String?

    // Follow-up
    public var lastFollowUpDate: Date?
    public var nextFollowUpDate: Date?
    public var followUpNotes: String?

    // Dates
    public var createdAt: Date
    public var updatedAt: Date
    public var closedAt: Date?
    public var closureReason: String?

    public init(
        caseId: DSPSCaseId = DSPSCaseId(),
        dspsStudentProfileEntityId: EntityId,
        termId: String,
        caseType: AccommodationCaseType = .termAccommodations,
        status: AccommodationCaseStatus = .new,
        priority: DSPSCasePriority = .normal,
        approvedAccommodations: [ApprovedAccommodation] = [],
        enrolledSections: [EnrolledSectionInfo] = [],
        accommodationLetterIds: [AccommodationLetterId] = [],
        lettersGeneratedAt: Date? = nil,
        lettersDeliveredAt: Date? = nil,
        assignedToId: String? = nil,
        intakeMeetingDate: Date? = nil,
        intakeMeetingCompletedAt: Date? = nil,
        accommodationsApprovedAt: Date? = nil,
        approvedBy: String? = nil,
        lastFollowUpDate: Date? = nil,
        nextFollowUpDate: Date? = nil,
        followUpNotes: String? = nil
    ) {
        self.caseId = caseId
        self.dspsStudentProfileEntityId = dspsStudentProfileEntityId
        self.termId = termId
        self.caseType = caseType
        self.status = status
        self.priority = priority
        self.approvedAccommodations = approvedAccommodations
        self.enrolledSections = enrolledSections
        self.accommodationLetterIds = accommodationLetterIds
        self.lettersGeneratedAt = lettersGeneratedAt
        self.lettersDeliveredAt = lettersDeliveredAt
        self.assignedToId = assignedToId
        self.intakeMeetingDate = intakeMeetingDate
        self.intakeMeetingCompletedAt = intakeMeetingCompletedAt
        self.accommodationsApprovedAt = accommodationsApprovedAt
        self.approvedBy = approvedBy
        self.lastFollowUpDate = lastFollowUpDate
        self.nextFollowUpDate = nextFollowUpDate
        self.followUpNotes = followUpNotes
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

public enum AccommodationCaseType: String, Codable, Sendable {
    case initialIntake              // New student intake
    case termAccommodations         // Term accommodation setup
    case accommodationChange        // Modification request
    case emergencyAccommodation     // Urgent accommodation need
    case testing                    // Testing accommodations only
    case altMedia                   // Alt-media focused case
    case appeal                     // Eligibility or accommodation appeal
}

public enum AccommodationCaseStatus: String, Codable, Sendable {
    case new
    case schedulingIntake
    case awaitingDocumentation
    case documentationReview
    case intakeScheduled
    case intakeCompleted
    case accommodationsApproved
    case lettersPending
    case lettersGenerated
    case lettersDelivered
    case active
    case followUpNeeded
    case onHold
    case closed
    case cancelled
}

public enum DSPSCasePriority: String, Codable, Sendable {
    case urgent                     // Same-day response needed
    case high                       // 1-2 day response
    case normal                     // Standard timeline
    case low                        // When time permits
}

/// An approved accommodation.
public struct ApprovedAccommodation: Codable, Sendable, Identifiable {
    public let id: UUID
    public var accommodationType: AccommodationType
    public var description: String
    public var approvalDate: Date
    public var approvedBy: String
    public var expirationDate: Date?
    public var courseSpecific: Bool            // True if only for certain courses
    public var applicableCourseTypes: [String] // If courseSpecific, which types
    public var notes: String?
    public var requiresSpecialArrangement: Bool

    public init(
        id: UUID = UUID(),
        accommodationType: AccommodationType,
        description: String,
        approvalDate: Date = Date(),
        approvedBy: String,
        expirationDate: Date? = nil,
        courseSpecific: Bool = false,
        applicableCourseTypes: [String] = [],
        notes: String? = nil,
        requiresSpecialArrangement: Bool = false
    ) {
        self.id = id
        self.accommodationType = accommodationType
        self.description = description
        self.approvalDate = approvalDate
        self.approvedBy = approvedBy
        self.expirationDate = expirationDate
        self.courseSpecific = courseSpecific
        self.applicableCourseTypes = applicableCourseTypes
        self.notes = notes
        self.requiresSpecialArrangement = requiresSpecialArrangement
    }
}

public enum AccommodationType: String, Codable, Sendable, CaseIterable {
    // Testing accommodations
    case extendedTestTime           // 1.5x, 2x, etc.
    case separateTestingRoom
    case reducedDistractionEnvironment
    case computerForEssays
    case reader
    case scribe
    case calculator
    case spellChecker
    case dictionary
    case breaksDuringExam

    // Classroom accommodations
    case preferentialSeating
    case noteServices
    case audioRecordingLectures
    case signLanguageInterpreter
    case realTimeCaptioning
    case accessibleFurniture
    case frequentBreaks
    case flexibleAttendance
    case earlyAccessToSyllabus

    // Alt-media accommodations
    case alternativeMediaTextbooks
    case alternativeMediaHandouts
    case largePrintMaterials
    case audioMaterials
    case brailleMaterials
    case electronicTextMaterials
    case accessibleDigitalContent

    // Assignment accommodations
    case extendedDeadlines
    case alternativeAssignments
    case reducedCourseLoad
    case priorityRegistration

    // Other
    case assistiveTechnology
    case serviceAnimal
    case parkingAccommodation
    case housingAccommodation
    case otherAccommodation
}

/// Info about an enrolled section for accommodation tracking.
public struct EnrolledSectionInfo: Codable, Sendable {
    public var sectionId: String               // Reference to Transcriptum section
    public var courseDesignation: String       // "CS 101"
    public var instructorName: String
    public var instructorEmail: String?
    public var letterDelivered: Bool
    public var letterDeliveredDate: Date?
    public var instructorAcknowledged: Bool
    public var instructorAcknowledgedDate: Date?
    public var instructorNotes: String?
    public var accommodationsImplemented: Bool
    public var implementationIssues: String?

    public init(
        sectionId: String,
        courseDesignation: String,
        instructorName: String,
        instructorEmail: String? = nil,
        letterDelivered: Bool = false,
        letterDeliveredDate: Date? = nil,
        instructorAcknowledged: Bool = false,
        instructorAcknowledgedDate: Date? = nil,
        instructorNotes: String? = nil,
        accommodationsImplemented: Bool = false,
        implementationIssues: String? = nil
    ) {
        self.sectionId = sectionId
        self.courseDesignation = courseDesignation
        self.instructorName = instructorName
        self.instructorEmail = instructorEmail
        self.letterDelivered = letterDelivered
        self.letterDeliveredDate = letterDeliveredDate
        self.instructorAcknowledged = instructorAcknowledged
        self.instructorAcknowledgedDate = instructorAcknowledgedDate
        self.instructorNotes = instructorNotes
        self.accommodationsImplemented = accommodationsImplemented
        self.implementationIssues = implementationIssues
    }
}

// MARK: - Alt-Media Request Component

/// A request for alternative media production.
/// Links to Diaplasion for actual production.
public struct AltMediaRequestComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "ada", "alt_media"]

    public let requestId: AltMediaRequestId
    public var dspsStudentProfileEntityId: EntityId
    public var accommodationCaseEntityId: EntityId?

    // Request details
    public var status: AltMediaRequestStatus
    public var priority: AltMediaPriority
    public var requestedFormats: [AltMediaFormat]

    // Source material
    public var materialType: MaterialType
    public var materialTitle: String
    public var materialAuthor: String?
    public var materialISBN: String?
    public var materialPublisher: String?
    public var materialEdition: String?
    public var materialChapters: String?       // Specific chapters if not whole book

    // Course context
    public var courseDesignation: String       // "CS 101"
    public var sectionId: String?
    public var instructorName: String?
    public var termId: String

    // Dates and deadlines
    public var requestDate: Date
    public var neededByDate: Date              // When student needs it
    public var classStartDate: Date?           // When class starts
    public var assignmentDueDate: Date?        // If for specific assignment

    // Production tracking
    public var assignedToId: String?
    public var productionStartedAt: Date?
    public var productionCompletedAt: Date?
    public var deliveredAt: Date?
    public var deliveryMethod: DeliveryMethod?

    // Diaplasion integration
    public var diaplasionJobEntityId: EntityId? // Link to Diaplasion processing job
    public var sourceDocumentPath: String?
    public var outputDocumentPaths: [String]

    // Quality and feedback
    public var qualityCheckedAt: Date?
    public var qualityCheckedBy: String?
    public var studentFeedback: String?
    public var studentSatisfactionRating: Int?  // 1-5

    // SLA tracking
    public var slaTargetDate: Date?
    public var slaMet: Bool?
    public var slaViolationReason: String?

    // Notes
    public var internalNotes: String?
    public var studentNotes: String?

    // Audit
    public var createdAt: Date
    public var updatedAt: Date
    public var createdBy: String

    public init(
        requestId: AltMediaRequestId = AltMediaRequestId(),
        dspsStudentProfileEntityId: EntityId,
        accommodationCaseEntityId: EntityId? = nil,
        status: AltMediaRequestStatus = .new,
        priority: AltMediaPriority = .standard,
        requestedFormats: [AltMediaFormat],
        materialType: MaterialType,
        materialTitle: String,
        materialAuthor: String? = nil,
        materialISBN: String? = nil,
        materialPublisher: String? = nil,
        materialEdition: String? = nil,
        materialChapters: String? = nil,
        courseDesignation: String,
        sectionId: String? = nil,
        instructorName: String? = nil,
        termId: String,
        requestDate: Date = Date(),
        neededByDate: Date,
        classStartDate: Date? = nil,
        assignmentDueDate: Date? = nil,
        createdBy: String
    ) {
        self.requestId = requestId
        self.dspsStudentProfileEntityId = dspsStudentProfileEntityId
        self.accommodationCaseEntityId = accommodationCaseEntityId
        self.status = status
        self.priority = priority
        self.requestedFormats = requestedFormats
        self.materialType = materialType
        self.materialTitle = materialTitle
        self.materialAuthor = materialAuthor
        self.materialISBN = materialISBN
        self.materialPublisher = materialPublisher
        self.materialEdition = materialEdition
        self.materialChapters = materialChapters
        self.courseDesignation = courseDesignation
        self.sectionId = sectionId
        self.instructorName = instructorName
        self.termId = termId
        self.requestDate = requestDate
        self.neededByDate = neededByDate
        self.classStartDate = classStartDate
        self.assignmentDueDate = assignmentDueDate
        self.createdAt = Date()
        self.updatedAt = Date()
        self.createdBy = createdBy
        self.outputDocumentPaths = []
    }

    /// Days until needed.
    public var daysUntilNeeded: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: neededByDate).day ?? 0
    }

    /// Whether this request is overdue.
    public var isOverdue: Bool {
        status != .delivered && status != .cancelled && Date() > neededByDate
    }
}

public enum AltMediaRequestStatus: String, Codable, Sendable {
    case new
    case acknowledged
    case sourcingMaterial           // Looking for source files
    case awaitingPublisherFiles     // Requested from publisher
    case receivedSourceFiles
    case inProduction
    case qualityCheck
    case readyForDelivery
    case delivered
    case onHold
    case cancelled
    case returnedForRevision
}

public enum AltMediaPriority: String, Codable, Sendable {
    case urgent                     // Needed within 24-48 hours
    case rush                       // Needed within 1 week
    case standard                   // Normal timeline (2-3 weeks)
    case low                        // No specific deadline
}

public enum MaterialType: String, Codable, Sendable {
    case textbook
    case labManual
    case coursePacket
    case article
    case handout
    case syllabus
    case exam
    case worksheet
    case presentation
    case video
    case webContent
    case software
    case other
}

public enum DeliveryMethod: String, Codable, Sendable {
    case email
    case studentPortal
    case cloudStorage
    case physicalMedia
    case inPerson
    case lms                        // Through Canvas/LMS
}

// MARK: - Accommodation Letter Component

/// An accommodation letter sent to an instructor.
public struct AccommodationLetterComponent: Component, SensitiveComponent, Sendable {
    public static let sensitivity: DataSensitivity = .restricted
    public static let dataCategories: Set<String> = ["ferpa", "ada", "accommodation_letter"]

    public let letterId: AccommodationLetterId
    public var accommodationCaseEntityId: EntityId
    public var dspsStudentProfileEntityId: EntityId

    // Letter details
    public var letterType: LetterType
    public var termId: String
    public var sectionId: String
    public var courseDesignation: String

    // Recipient
    public var recipientName: String
    public var recipientEmail: String
    public var recipientDepartment: String?

    // Content
    public var accommodationsIncluded: [AccommodationType]
    public var customText: String?
    public var generatedContent: String?       // The actual letter text

    // Delivery
    public var generatedAt: Date?
    public var sentAt: Date?
    public var sentBy: String?
    public var deliveryMethod: LetterDeliveryMethod
    public var deliveryConfirmed: Bool
    public var deliveryConfirmedAt: Date?

    // Acknowledgment
    public var acknowledged: Bool
    public var acknowledgedAt: Date?
    public var acknowledgedBy: String?
    public var acknowledgedVia: String?        // Email, portal, in-person

    // Follow-up
    public var followUpNeeded: Bool
    public var followUpReason: String?
    public var followUpCompletedAt: Date?

    public var createdAt: Date

    public init(
        letterId: AccommodationLetterId = AccommodationLetterId(),
        accommodationCaseEntityId: EntityId,
        dspsStudentProfileEntityId: EntityId,
        letterType: LetterType = .termAccommodations,
        termId: String,
        sectionId: String,
        courseDesignation: String,
        recipientName: String,
        recipientEmail: String,
        recipientDepartment: String? = nil,
        accommodationsIncluded: [AccommodationType],
        customText: String? = nil,
        generatedContent: String? = nil,
        deliveryMethod: LetterDeliveryMethod = .email
    ) {
        self.letterId = letterId
        self.accommodationCaseEntityId = accommodationCaseEntityId
        self.dspsStudentProfileEntityId = dspsStudentProfileEntityId
        self.letterType = letterType
        self.termId = termId
        self.sectionId = sectionId
        self.courseDesignation = courseDesignation
        self.recipientName = recipientName
        self.recipientEmail = recipientEmail
        self.recipientDepartment = recipientDepartment
        self.accommodationsIncluded = accommodationsIncluded
        self.customText = customText
        self.generatedContent = generatedContent
        self.deliveryMethod = deliveryMethod
        self.deliveryConfirmed = false
        self.acknowledged = false
        self.followUpNeeded = false
        self.createdAt = Date()
    }
}

public enum LetterType: String, Codable, Sendable {
    case termAccommodations         // Standard term letter
    case testingOnly                // Testing accommodations only
    case update                     // Update to existing letter
    case reminder                   // Reminder/follow-up
    case emergency                  // Urgent accommodation need
}

public enum LetterDeliveryMethod: String, Codable, Sendable {
    case email
    case facultyPortal
    case inPerson
    case departmentOffice
    case mail
}
