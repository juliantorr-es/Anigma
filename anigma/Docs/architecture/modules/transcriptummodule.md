> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# TranscriptumModule

## Overview

TranscriptumModule is a Swift module in the Anigma ecosystem with **1725 lines of code** across **4 files**.

## Statistics

- **Public Types**: 51
- **Public Functions**: 22  
- **Components**: 40
- **Systems**: 0
- **Services**: 4

## Architecture

### Components
- `TermComponent`
- `TermType`
- `TermStatus`
- `ProgramComponent`
- `ProgramType`
- `AwardType`
- `CourseComponent`
- `CourseType`
- `GradingMode`
- `TransferStatus`
- `PrerequisiteRequirement`
- `CourseSectionComponent`
- `SectionMeeting`
- `Weekday`
- `MeetingType`
- `InstructionMode`
- `SectionStatus`
- `StudentAcademicProfileComponent`
- `DeclaredProgram`
- `ProgramDeclarationStatus`
- `EnrollmentStatus`
- `StudentType`
- `ResidencyStatus`
- `AcademicLevel`
- `StudentFlag`
- `AcademicHold`
- `HoldType`
- `EnrollmentComponent`
- `EnrollmentRecordStatus`
- `EnrollmentType`
- `GradingBasis`
- `WithdrawalReason`
- `GradeRecordComponent`
- `GradeType`
- `GradeChange`
- `AcademicStandingComponent`
- `StandingType`
- `DegreeAwardComponent`
- `HonorsDesignation`
- `AwardStatus`

### Systems
No systems found

### Services
- `StudentTranscript`
- `TranscriptTermEntry`
- `TranscriptCourseEntry`
- `TranscriptumError`

## Dependencies

- `AnigmaCore`

## File Structure


### Components/AcademicComponents.swift

- **Lines**: 528
- **Public Types**: 17
- **Public Functions**: 0


**Public Types:**
- `struct TermComponent` (line 15)
- `enum TermType` (line 65)
- `enum TermStatus` (line 74)
- `struct ProgramComponent` (line 86)
- `enum ProgramType` (line 167)
- `enum AwardType` (line 176)
- `struct CourseComponent` (line 193)
- `enum CourseType` (line 313)
- `enum GradingMode` (line 323)
- `enum TransferStatus` (line 331)
- `struct PrerequisiteRequirement` (line 338)
- `struct CourseSectionComponent` (line 366)
- `struct SectionMeeting` (line 459)
- `enum Weekday` (line 492)
- `enum MeetingType` (line 502)
- `enum InstructionMode` (line 513)
- `enum SectionStatus` (line 521)




### Components/StudentRecordComponents.swift

- **Lines**: 651
- **Public Types**: 23
- **Public Functions**: 0


**Public Types:**
- `struct StudentAcademicProfileComponent` (line 17)
- `struct DeclaredProgram` (line 106)
- `enum ProgramDeclarationStatus` (line 131)
- `enum EnrollmentStatus` (line 138)
- `enum StudentType` (line 149)
- `enum ResidencyStatus` (line 157)
- `enum AcademicLevel` (line 166)
- `enum StudentFlag` (line 175)
- `struct AcademicHold` (line 191)
- `enum HoldType` (line 223)
- `struct EnrollmentComponent` (line 240)
- `enum EnrollmentRecordStatus` (line 321)
- `enum EnrollmentType` (line 331)
- `enum GradingBasis` (line 340)
- `enum WithdrawalReason` (line 347)
- `struct GradeRecordComponent` (line 362)
- `enum GradeType` (line 446)
- `struct GradeChange` (line 455)
- `struct AcademicStandingComponent` (line 486)
- `enum StandingType` (line 555)
- `struct DegreeAwardComponent` (line 568)
- `enum HonorsDesignation` (line 636)
- `enum AwardStatus` (line 645)




### Services/TranscriptumService.swift

- **Lines**: 412
- **Public Types**: 4
- **Public Functions**: 21


**Public Types:**
- `struct StudentTranscript` (line 343)
- `struct TranscriptTermEntry` (line 357)
- `struct TranscriptCourseEntry` (line 366)
- `enum TranscriptumError` (line 375)



**Public Functions:**
- `getCurrentTerm` (line 33)
- `getTerm` (line 39)
- `getTerms` (line 45)
- `getProgram` (line 53)
- `getActivePrograms` (line 59)
- `getPrograms` (line 65)
- `getCourse` (line 73)
- `getCourses` (line 79)
- `searchCourses` (line 85)
- `getSections` (line 98)
- `getSections` (line 104)
- `getOpenSections` (line 114)
- `getStudentProfile` (line 122)
- `getEnrollments` (line 128)
- `getGradeHistory` (line 139)
- `getStandingHistory` (line 147)
- `getDegreeAwards` (line 155)
- `enrollStudent` (line 163)
- `dropStudent` (line 207)
- `submitGrade` (line 238)
- `generateTranscript` (line 285)


### TranscriptumModule.swift

- **Lines**: 134
- **Public Types**: 7
- **Public Functions**: 1


**Public Types:**
- `enum TranscriptumModule` (line 24)
- `struct TermId` (line 82)
- `struct ProgramId` (line 91)
- `struct CourseId` (line 100)
- `struct SectionId` (line 109)
- `struct EnrollmentId` (line 118)
- `struct StudentRecordId` (line 127)



**Public Functions:**
- `initialize` (static) (line 29)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
