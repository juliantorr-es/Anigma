//
//  DaemonServer+Transcriptum.swift
//  AnigmaDaemonCore
//

import Foundation
import TranscriptumModule
import AnigmaCore
import ContractsCore

extension DaemonServer {
    // MARK: - Transcriptum Handlers

    func handleTranscriptumGetStudentProfile(
        ctx: DaemonRequestContext,
        studentId: String
    ) async throws -> StudentAcademicProfileComponent? {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "transcriptum.student.read")
        let result = try await transcriptumService.getStudentProfile(studentId: studentId)
        return result?.1
    }

    func handleTranscriptumGetTranscript(
        ctx: DaemonRequestContext,
        studentRecordId: StudentRecordId
    ) async throws -> StudentTranscript {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "transcriptum.transcript.read")
        return try await transcriptumService.generateTranscript(studentRecordId: studentRecordId)
    }

    func handleTranscriptumEnroll(
        ctx: DaemonRequestContext,
        studentRecordId: StudentRecordId,
        sectionId: SectionId,
        termId: TermId,
        units: Double
    ) async throws -> EntityId {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "transcriptum.enrollment.write")
        return try await transcriptumService.enrollStudent(
            studentRecordId: studentRecordId,
            sectionId: sectionId,
            termId: termId,
            units: units
        )
    }

    func handleTranscriptumSubmitGrade(
        ctx: DaemonRequestContext,
        enrollmentId: EnrollmentId,
        grade: String,
        gradePoints: Double?,
        unitsEarned: Double
    ) async throws -> EntityId {
        _ = try await tokenManager.validateToken(ctx.capabilityToken, requiredScope: "transcriptum.grade.write")
        return try await transcriptumService.submitGrade(
            enrollmentId: enrollmentId,
            grade: grade,
            gradePoints: gradePoints,
            unitsEarned: unitsEarned
        )
    }
}
