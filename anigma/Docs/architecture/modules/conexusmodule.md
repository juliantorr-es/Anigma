> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# ConexusModule

## Overview

ConexusModule is a Swift module in the Anigma ecosystem with **2743 lines of code** across **9 files**.

## Statistics

- **Public Types**: 63
- **Public Functions**: 31  
- **Components**: 41
- **Systems**: 0
- **Services**: 2

## Architecture

### Components
- `ActivityComponent`
- `ActivityDirection`
- `CaseComponent`
- `ResolutionType`
- `ContactComponent`
- `EmailAddress`
- `EmailType`
- `PhoneNumber`
- `PhoneType`
- `MailingAddress`
- `AddressType`
- `ContactMethod`
- `AccessibleFormat`
- `DSPSCaseId`
- `AltMediaRequestId`
- `AccommodationLetterId`
- `StudentDSPSProfileComponent`
- `DSPSEligibilityStatus`
- `DisabilityCategory`
- `AltMediaFormat`
- `CommunicationMethod`
- `AccommodationCaseComponent`
- `AccommodationCaseType`
- `AccommodationCaseStatus`
- `DSPSCasePriority`
- `ApprovedAccommodation`
- `AccommodationType`
- `EnrolledSectionInfo`
- `AltMediaRequestComponent`
- `AltMediaRequestStatus`
- `AltMediaPriority`
- `MaterialType`
- `DeliveryMethod`
- `AccommodationLetterComponent`
- `LetterType`
- `LetterDeliveryMethod`
- `DealComponent`
- `OrganizationComponent`
- `RelationshipId`
- `RelationshipComponent`
- `RelationshipEndType`

### Systems
No systems found

### Services
- `StageSummary`
- `PipelineSummary`

## Dependencies

- `AnigmaCore`
- `ContractsCore`

## File Structure


### Components/ActivityComponent.swift

- **Lines**: 234
- **Public Types**: 2
- **Public Functions**: 5


**Public Types:**
- `struct ActivityComponent` (line 12)
- `enum ActivityDirection` (line 123)



**Public Functions:**
- `call` (static) (line 132)
- `email` (static) (line 152)
- `meeting` (static) (line 170)
- `note` (static) (line 192)
- `task` (static) (line 213)


### Components/CaseComponent.swift

- **Lines**: 183
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct CaseComponent` (line 12)
- `enum ResolutionType` (line 173)




### Components/ContactComponent.swift

- **Lines**: 247
- **Public Types**: 9
- **Public Functions**: 0


**Public Types:**
- `struct ContactComponent` (line 12)
- `struct EmailAddress` (line 133)
- `enum EmailType` (line 146)
- `struct PhoneNumber` (line 155)
- `enum PhoneType` (line 168)
- `struct MailingAddress` (line 178)
- `enum AddressType` (line 208)
- `enum ContactMethod` (line 227)
- `enum AccessibleFormat` (line 237)




### Components/DSPSComponents.swift

- **Lines**: 739
- **Public Types**: 23
- **Public Functions**: 0


**Public Types:**
- `struct DSPSCaseId` (line 17)
- `struct AltMediaRequestId` (line 26)
- `struct AccommodationLetterId` (line 35)
- `struct StudentDSPSProfileComponent` (line 47)
- `enum DSPSEligibilityStatus` (line 156)
- `enum DisabilityCategory` (line 168)
- `enum AltMediaFormat` (line 184)
- `enum CommunicationMethod` (line 199)
- `struct AccommodationCaseComponent` (line 212)
- `enum AccommodationCaseType` (line 299)
- `enum AccommodationCaseStatus` (line 309)
- `enum DSPSCasePriority` (line 327)
- `struct ApprovedAccommodation` (line 335)
- `enum AccommodationType` (line 372)
- `struct EnrolledSectionInfo` (line 420)
- `struct AltMediaRequestComponent` (line 464)
- `enum AltMediaRequestStatus` (line 592)
- `enum AltMediaPriority` (line 607)
- `enum MaterialType` (line 614)
- `enum DeliveryMethod` (line 630)
- `struct AccommodationLetterComponent` (line 642)
- `enum LetterType` (line 724)
- `enum LetterDeliveryMethod` (line 732)




### Components/DealComponent.swift

- **Lines**: 140
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct DealComponent` (line 12)




### Components/OrganizationComponent.swift

- **Lines**: 104
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct OrganizationComponent` (line 12)




### Components/RelationshipComponent.swift

- **Lines**: 158
- **Public Types**: 3
- **Public Functions**: 4


**Public Types:**
- `struct RelationshipId` (line 12)
- `struct RelationshipComponent` (line 22)
- `enum RelationshipEndType` (line 86)



**Public Functions:**
- `employedBy` (static) (line 95)
- `manages` (static) (line 115)
- `memberOf` (static) (line 129)
- `referredBy` (static) (line 145)


### ConexusModule.swift

- **Lines**: 444
- **Public Types**: 20
- **Public Functions**: 6


**Public Types:**
- `enum ConexusModule` (line 27)
- `struct ContactId` (line 51)
- `struct OrganizationId` (line 66)
- `struct DealId` (line 81)
- `struct CaseId` (line 96)
- `struct ActivityId` (line 111)
- `struct PipelineId` (line 121)
- `enum ContactType` (line 133)
- `enum RelationshipType` (line 145)
- `enum OrganizationType` (line 161)
- `enum PipelineType` (line 175)
- `struct PipelineStage` (line 189)
- `struct PipelineDefinition` (line 230)
- `enum ActivityType` (line 292)
- `enum CaseType` (line 307)
- `enum CasePriority` (line 319)
- `enum CaseStatus` (line 342)
- `struct ContactAccessCheck` (line 365)
- `struct PipelineStageCheck` (line 387)
- `enum ConexusError` (line 410)



**Public Functions:**
- `initialize` (static) (line 32)
- `validNextStages` (line 255)
- `appliesTo` (line 372)
- `evaluate` (line 377)
- `appliesTo` (line 394)
- `evaluate` (line 398)


### Services/ConexusService.swift

- **Lines**: 494
- **Public Types**: 2
- **Public Functions**: 16


**Public Types:**
- `struct StageSummary` (line 469)
- `struct PipelineSummary` (line 477)



**Public Functions:**
- `createContact` (line 33)
- `getContact` (line 73)
- `updateContact` (line 78)
- `findContacts` (line 106)
- `createOrganization` (line 125)
- `getOrganization` (line 164)
- `createDeal` (line 171)
- `moveDeal` (line 218)
- `getPipelineSummary` (line 279)
- `createCase` (line 316)
- `updateCaseStatus` (line 358)
- `logActivity` (line 396)
- `getActivityTimeline` (line 430)
- `registerPipeline` (line 451)
- `getPipeline` (line 456)
- `listPipelines` (line 461)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
