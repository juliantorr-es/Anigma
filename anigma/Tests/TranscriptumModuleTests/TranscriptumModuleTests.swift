//
//  TranscriptumModuleTests.swift
//  TranscriptumModuleTests
//
//  Tests for the Transcriptum academic records domain.
//

import XCTest
@testable import AnigmaCore
@testable import TranscriptumModule
import AnigmaPrimitives

final class TranscriptumModuleTests: XCTestCase {

    // MARK: - Component Tests

    func testTermComponentCreation() {
        let term = TermComponent(
            termId: TermId("2025SP"),
            name: "Spring 2025",
            code: "2025SP",
            termType: .spring,
            academicYear: "2024-2025",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 120)
        )

        XCTAssertEqual(term.termId.value, "2025SP")
        XCTAssertEqual(term.name, "Spring 2025")
        XCTAssertEqual(term.termType, .spring)
        XCTAssertEqual(term.status, .scheduled)
    }

    func testProgramComponentCreation() {
        let program = ProgramComponent(
            programId: ProgramId("CS-AS"),
            title: "Associate in Science: Computer Science",
            shortTitle: "CS AS",
            programType: .degree,
            awardType: .associateScience,
            departmentId: "CSCI",
            totalUnitsRequired: 60.0,
            minimumGPA: 2.0,
            catalogYear: "2024-2025"
        )

        XCTAssertEqual(program.programId.value, "CS-AS")
        XCTAssertEqual(program.awardType, .associateScience)
        XCTAssertEqual(program.totalUnitsRequired, 60.0)
        XCTAssertTrue(program.isActive)
    }

    func testCourseComponentDesignation() {
        let course = CourseComponent(
            courseId: CourseId("CS-101"),
            subject: "CS",
            number: "101",
            title: "Introduction to Computer Science",
            shortTitle: "Intro to CS",
            creditUnits: 3.0,
            catalogYear: "2024-2025"
        )

        XCTAssertEqual(course.designation, "CS 101")
        XCTAssertEqual(course.creditUnits, 3.0)
        XCTAssertTrue(course.isActive)
    }

    func testCourseSectionCapacity() {
        var section = CourseSectionComponent(
            sectionId: SectionId("CS-101-001-2025SP"),
            courseId: CourseId("CS-101"),
            termId: TermId("2025SP"),
            sectionNumber: "001",
            enrollmentCapacity: 30,
            enrolledCount: 25,
            waitlistCapacity: 10,
            waitlistedCount: 3
        )

        XCTAssertEqual(section.availableSeats, 5)
        XCTAssertFalse(section.isFull)

        section.enrolledCount = 30
        XCTAssertEqual(section.availableSeats, 0)
        XCTAssertTrue(section.isFull)
    }

    func testSectionMeetingLocation() {
        let meeting = SectionMeeting(
            days: [.monday, .wednesday, .friday],
            startTime: "09:00",
            endTime: "09:50",
            buildingCode: "BATL",
            roomNumber: "201"
        )

        XCTAssertEqual(meeting.location, "BATL 201")
        XCTAssertTrue(meeting.days.contains(.monday))
        XCTAssertTrue(meeting.days.contains(.wednesday))
        XCTAssertTrue(meeting.days.contains(.friday))
        XCTAssertFalse(meeting.days.contains(.tuesday))
    }

    // MARK: - Student Record Tests

    func testStudentAcademicProfileSensitivity() {
        XCTAssertEqual(StudentAcademicProfileComponent.sensitivity, .restricted)
        XCTAssertTrue(StudentAcademicProfileComponent.dataCategories.contains("ferpa"))
        XCTAssertTrue(StudentAcademicProfileComponent.dataCategories.contains("student_record"))
    }

    func testEnrollmentComponentSensitivity() {
        XCTAssertEqual(EnrollmentComponent.sensitivity, .restricted)
        XCTAssertTrue(EnrollmentComponent.dataCategories.contains("ferpa"))
    }

    func testGradeRecordSensitivity() {
        XCTAssertEqual(GradeRecordComponent.sensitivity, .restricted)
        XCTAssertTrue(GradeRecordComponent.dataCategories.contains("grade"))
    }

    func testDeclaredProgram() {
        let declared = DeclaredProgram(
            programId: ProgramId("CS-AS"),
            status: .active,
            catalogYear: "2024-2025",
            isPrimary: true
        )

        XCTAssertEqual(declared.status, .active)
        XCTAssertTrue(declared.isPrimary)
    }

    func testAcademicHoldActive() {
        let activeHold = AcademicHold(
            holdType: .registration,
            reason: "Outstanding balance",
            placedBy: "Bursar"
        )

        XCTAssertTrue(activeHold.isActive)

        var clearedHold = activeHold
        clearedHold.clearedDate = Date()
        clearedHold.clearedBy = "Bursar"

        XCTAssertFalse(clearedHold.isActive)
    }

    func testEnrollmentCreation() {
        let enrollment = EnrollmentComponent(
            studentRecordId: StudentRecordId("12345678"),
            sectionId: SectionId("CS-101-001-2025SP"),
            termId: TermId("2025SP"),
            status: .enrolled,
            gradingBasis: .letter,
            unitsAttempted: 3.0,
            createdBy: "system"
        )

        XCTAssertEqual(enrollment.status, .enrolled)
        XCTAssertEqual(enrollment.gradingBasis, .letter)
        XCTAssertEqual(enrollment.unitsAttempted, 3.0)
        XCTAssertFalse(enrollment.isRepeat)
    }

    func testGradeRecordQualityPoints() {
        let grade = GradeRecordComponent(
            enrollmentId: EnrollmentId(),
            studentRecordId: StudentRecordId("12345678"),
            sectionId: SectionId("CS-101-001-2025SP"),
            termId: TermId("2025SP"),
            courseId: CourseId("CS-101"),
            grade: "A",
            gradePoints: 4.0,
            unitsEarned: 3.0,
            unitsAttempted: 3.0,
            qualityPoints: 12.0,  // 4.0 * 3.0
            submittedBy: "instructor001"
        )

        XCTAssertEqual(grade.grade, "A")
        XCTAssertEqual(grade.gradePoints, 4.0)
        XCTAssertEqual(grade.qualityPoints, 12.0)
        XCTAssertTrue(grade.isIncludedInGPA)
    }

    func testAcademicStanding() {
        let standing = AcademicStandingComponent(
            studentRecordId: StudentRecordId("12345678"),
            termId: TermId("2025SP"),
            standing: .goodStanding,
            termGPA: 3.5,
            termUnitsAttempted: 12.0,
            termUnitsEarned: 12.0,
            cumulativeGPA: 3.4,
            cumulativeUnitsAttempted: 45.0,
            cumulativeUnitsEarned: 45.0
        )

        XCTAssertEqual(standing.standing, .goodStanding)
        XCTAssertEqual(standing.termGPA, 3.5)
    }

    func testDegreeAward() {
        let award = DegreeAwardComponent(
            studentRecordId: StudentRecordId("12345678"),
            programId: ProgramId("CS-AS"),
            awardType: .associateScience,
            awardTitle: "Associate in Science: Computer Science",
            honors: .highHonors,
            conferralDate: Date(),
            conferralTermId: TermId("2025SP"),
            finalGPA: 3.75,
            totalUnitsEarned: 62.0,
            requirementsMetDate: Date()
        )

        XCTAssertEqual(award.honors, .highHonors)
        XCTAssertEqual(award.status, .conferred)
        XCTAssertEqual(award.finalGPA, 3.75)
    }

    // MARK: - Sync Infrastructure Tests

    func testDomainSyncConfig() {
        let config = DomainSyncConfig(
            domainName: "AcademicRecords",
            authority: .external,
            externalSystemId: "banner",
            syncEnabled: true,
            syncIntervalSeconds: 300
        )

        XCTAssertEqual(config.domainName, "AcademicRecords")
        XCTAssertEqual(config.authority, .external)
        XCTAssertTrue(config.syncEnabled)
    }

    func testSyncAuthorityChange() async {
        let syncManager = SyncManager()

        let config = DomainSyncConfig(
            domainName: "AcademicRecords",
            authority: .external
        )
        await syncManager.registerDomain(config)

        // Verify initial config
        let initial = await syncManager.getConfig(for: "AcademicRecords")
        XCTAssertEqual(initial?.authority, .external)

        // Change authority (the "flip the switch" operation)
        await syncManager.setAuthority(for: "AcademicRecords", to: .anigma, by: "admin")

        let updated = await syncManager.getConfig(for: "AcademicRecords")
        XCTAssertEqual(updated?.authority, .anigma)
    }

    func testSyncRecordLinkage() async {
        let syncManager = SyncManager()

        let entityId = EntityId()
        await syncManager.linkRecord(systemId: "banner", externalId: "STU12345", to: entityId)

        let linked = await syncManager.getLinkedEntity(systemId: "banner", externalId: "STU12345")
        XCTAssertEqual(linked, entityId)

        let externalId = await syncManager.getLinkedExternalId(systemId: "banner", entityId: entityId)
        XCTAssertEqual(externalId, "STU12345")
    }

    func testSyncStats() async {
        let syncManager = SyncManager()

        let stats = await syncManager.getStats()
        XCTAssertEqual(stats.totalOperations, 0)
        XCTAssertEqual(stats.successRate, 0)
    }

    func testAnyCodableValue() throws {
        // Test string
        let stringValue = AnyCodableValue.string("hello")
        XCTAssertEqual(stringValue.stringValue, "hello")

        // Test int
        let intValue = AnyCodableValue.int(42)
        XCTAssertEqual(intValue.intValue, 42)

        // Test encoding/decoding
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encoded = try encoder.encode(stringValue)
        let decoded = try decoder.decode(AnyCodableValue.self, from: encoded)
        XCTAssertEqual(decoded, stringValue)
    }

    func testSyncMetadataComponent() {
        var metadata = SyncMetadataComponent()

        XCTAssertTrue(metadata.syncedSystems.isEmpty)

        let info = SyncedSystemInfo(
            systemId: "banner",
            externalId: "STU12345",
            syncDirection: .inbound
        )
        metadata.addSyncedSystem(info)

        XCTAssertEqual(metadata.syncedSystems.count, 1)
        XCTAssertEqual(metadata.syncedSystems[0].systemId, "banner")
        XCTAssertNotNil(metadata.lastSyncAt)
    }

    // MARK: - World Integration Tests

    func testAcademicRecordsInWorld() async {
        let world = World()

        // Create entities
        let termEntity = await world.createEntity()
        let courseEntity = await world.createEntity()
        let studentEntity = await world.createEntity()

        // Add term
        let term = TermComponent(
            termId: TermId("2025SP"),
            name: "Spring 2025",
            code: "2025SP",
            termType: .spring,
            academicYear: "2024-2025",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 120),
            isCurrentTerm: true
        )
        await world.addComponent(termEntity, term)

        // Add course
        let course = CourseComponent(
            courseId: CourseId("CS-101"),
            subject: "CS",
            number: "101",
            title: "Introduction to Computer Science",
            shortTitle: "Intro to CS",
            creditUnits: 3.0,
            catalogYear: "2024-2025"
        )
        await world.addComponent(courseEntity, course)

        // Add student profile
        let profile = StudentAcademicProfileComponent(
            studentRecordId: StudentRecordId("12345678"),
            studentId: "12345678",
            enrollmentStatus: .enrolled,
            academicLevel: .freshman
        )
        await world.addComponent(studentEntity, profile)

        // Query and verify
        let terms = await world.query(TermComponent.self)
        XCTAssertEqual(terms.count, 1)
        XCTAssertTrue(terms[0].1.isCurrentTerm)

        let courses = await world.query(CourseComponent.self)
        XCTAssertEqual(courses.count, 1)
        XCTAssertEqual(courses[0].1.designation, "CS 101")

        let profiles = await world.query(StudentAcademicProfileComponent.self)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].1.enrollmentStatus, .enrolled)
    }

    func testEnrollmentWorkflow() async {
        let world = World()

        // Setup: Create section
        let sectionEntity = await world.createEntity()
        var section = CourseSectionComponent(
            sectionId: SectionId("CS-101-001-2025SP"),
            courseId: CourseId("CS-101"),
            termId: TermId("2025SP"),
            sectionNumber: "001",
            enrollmentCapacity: 30,
            enrolledCount: 25
        )
        await world.addComponent(sectionEntity, section)

        // Create enrollment
        let enrollmentEntity = await world.createEntity()
        let enrollment = EnrollmentComponent(
            studentRecordId: StudentRecordId("12345678"),
            sectionId: SectionId("CS-101-001-2025SP"),
            termId: TermId("2025SP"),
            status: .enrolled,
            gradingBasis: .letter,
            unitsAttempted: 3.0,
            createdBy: "system"
        )
        await world.addComponent(enrollmentEntity, enrollment)

        // Update section count
        section.enrolledCount = 26
        await world.addComponent(sectionEntity, section)

        // Verify
        let sections = await world.query(CourseSectionComponent.self)
        XCTAssertEqual(sections[0].1.enrolledCount, 26)
        XCTAssertEqual(sections[0].1.availableSeats, 4)

        let enrollments = await world.query(EnrollmentComponent.self)
        XCTAssertEqual(enrollments.count, 1)
        XCTAssertEqual(enrollments[0].1.status, .enrolled)
    }
}
