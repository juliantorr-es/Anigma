> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# CodexModule

## Overview

CodexModule is a Swift module in the Anigma ecosystem with **1977 lines of code** across **7 files**.

## Statistics

- **Public Types**: 25
- **Public Functions**: 34  
- **Components**: 8
- **Systems**: 0
- **Services**: 0

## Architecture

### Components
- `PageCommentComponent`
- `CommentReaction`
- `PageComponent`
- `PageVersionComponent`
- `SpaceComponent`
- `TemplateComponent`
- `TemplatePlaceholder`
- `PlaceholderType`

### Systems
No systems found

### Services
No services found

## Dependencies

- `AnigmaCore`
- `ContractsCore`

## File Structure


### CodexModule.swift

- **Lines**: 360
- **Public Types**: 17
- **Public Functions**: 5


**Public Types:**
- `enum CodexModule` (line 26)
- `struct SpaceId` (line 50)
- `struct PageId` (line 65)
- `struct TemplateId` (line 80)
- `struct CommentId` (line 90)
- `struct VersionId` (line 100)
- `enum SpaceType` (line 112)
- `enum ContentVisibility` (line 124)
- `enum PageType` (line 135)
- `enum PageStatus` (line 152)
- `enum ContentFormat` (line 182)
- `enum TemplateCategory` (line 192)
- `struct ContentAccessCheck` (line 206)
- `struct PublishApprovalCheck` (line 228)
- `enum CodexError` (line 251)
- `struct ContentSearchQuery` (line 292)
- `struct ContentSearchResult` (line 333)



**Public Functions:**
- `initialize` (static) (line 31)
- `appliesTo` (line 213)
- `evaluate` (line 218)
- `appliesTo` (line 235)
- `evaluate` (line 240)


### Components/PageCommentComponent.swift

- **Lines**: 158
- **Public Types**: 2
- **Public Functions**: 0


**Public Types:**
- `struct PageCommentComponent` (line 12)
- `struct CommentReaction` (line 147)




### Components/PageComponent.swift

- **Lines**: 252
- **Public Types**: 1
- **Public Functions**: 2


**Public Types:**
- `struct PageComponent` (line 12)



**Public Functions:**
- `generateSlug` (static) (line 129)
- `path` (line 160)


### Components/PageVersionComponent.swift

- **Lines**: 108
- **Public Types**: 1
- **Public Functions**: 1


**Public Types:**
- `struct PageVersionComponent` (line 12)



**Public Functions:**
- `from` (static) (line 68)


### Components/SpaceComponent.swift

- **Lines**: 118
- **Public Types**: 1
- **Public Functions**: 0


**Public Types:**
- `struct SpaceComponent` (line 12)




### Components/TemplateComponent.swift

- **Lines**: 419
- **Public Types**: 3
- **Public Functions**: 6


**Public Types:**
- `struct TemplateComponent` (line 12)
- `struct TemplatePlaceholder` (line 113)
- `enum PlaceholderType` (line 141)



**Public Functions:**
- `apply` (line 84)
- `validate` (line 99)
- `meetingNotes` (static) (line 155)
- `decisionRecord` (static) (line 206)
- `runbook` (static) (line 272)
- `altMediaRequest` (static) (line 346)


### Services/CodexService.swift

- **Lines**: 562
- **Public Types**: 0
- **Public Functions**: 20




**Public Functions:**
- `createSpace` (line 26)
- `getSpace` (line 67)
- `findSpace` (line 72)
- `listSpaces` (line 84)
- `createPage` (line 108)
- `getPage` (line 168)
- `updatePage` (line 173)
- `publishPage` (line 230)
- `archivePage` (line 269)
- `getPages` (line 294)
- `getChildPages` (line 318)
- `getVersionHistory` (line 335)
- `getLatestVersion` (line 356)
- `addComment` (line 364)
- `getComments` (line 399)
- `registerTemplate` (line 422)
- `getTemplate` (line 427)
- `listTemplates` (line 432)
- `createPageFromTemplate` (line 450)
- `search` (line 487)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
