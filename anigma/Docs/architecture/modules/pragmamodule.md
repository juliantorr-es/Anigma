> **🔄 RENOVATING FOR SATURATION**  
> This module inventory is currently being mapped to a **Decoupled Saturation Lane (DSL)**. See `Docs/architecture/SATURATED_MODULE_MAPPING.md` for the new role.

# PragmaModule

## Overview

PragmaModule is a Swift module in the Anigma ecosystem with **3256 lines of code** across **8 files**.

## Statistics

- **Public Types**: 49
- **Public Functions**: 70  
- **Components**: 18
- **Systems**: 0
- **Services**: 20

## Architecture

### Components
- `CommentComponent`
- `CommentType`
- `CommentReaction`
- `DiscussionThread`
- `NotificationComponent`
- `NotificationType`
- `NotificationPriority`
- `NotificationCategory`
- `NotificationPreferences`
- `DigestFrequency`
- `NotificationInbox`
- `ProjectComponent`
- `ProjectStatus`
- `ProjectSettings`
- `EstimateUnit`
- `ProjectSummary`
- `TaskComponent`
- `TaskSummary`

### Systems
No systems found

### Services
- `AutomationRule`
- `AutomationTrigger`
- `WorkEventType`
- `WorkEvent`
- `AutomationCondition`
- `ConditionOperator`
- `AutomationAction`
- `PragmaActionType`
- `AutomationExecution`
- `AutomationError`
- `ListView`
- `BoardView`
- `BoardColumn`
- `TimelineView`
- `TimelineItem`
- `DashboardView`
- `TaskFilter`
- `TaskSort`
- `SavedView`
- `SavedViewType`

## Dependencies

- `AnigmaCore`
- `ContractsCore`

## File Structure


### Components/CommentComponent.swift

- **Lines**: 268
- **Public Types**: 4
- **Public Functions**: 4


**Public Types:**
- `struct CommentComponent` (line 12)
- `enum CommentType` (line 98)
- `struct CommentReaction` (line 152)
- `struct DiscussionThread` (line 235)



**Public Functions:**
- `statusChange` (static) (line 168)
- `assignmentChange` (static) (line 184)
- `workLog` (static) (line 211)
- `replies` (line 254)


### Components/NotificationComponent.swift

- **Lines**: 398
- **Public Types**: 7
- **Public Functions**: 5


**Public Types:**
- `struct NotificationComponent` (line 12)
- `enum NotificationType` (line 122)
- `enum NotificationPriority` (line 181)
- `enum NotificationCategory` (line 194)
- `struct NotificationPreferences` (line 224)
- `enum DigestFrequency` (line 275)
- `struct NotificationInbox` (line 286)



**Public Functions:**
- `shouldDeliver` (line 252)
- `assigned` (static) (line 322)
- `mentioned` (static) (line 341)
- `dueSoon` (static) (line 360)
- `overdue` (static) (line 382)


### Components/ProjectComponent.swift

- **Lines**: 297
- **Public Types**: 5
- **Public Functions**: 1


**Public Types:**
- `struct ProjectComponent` (line 13)
- `enum ProjectStatus` (line 162)
- `struct ProjectSettings` (line 193)
- `enum EstimateUnit` (line 240)
- `struct ProjectSummary` (line 265)



**Public Functions:**
- `previewNextKey` (line 154)


### Components/TaskComponent.swift

- **Lines**: 263
- **Public Types**: 2
- **Public Functions**: 6


**Public Types:**
- `struct TaskComponent` (line 14)
- `struct TaskSummary` (line 240)



**Public Functions:**
- `withStatus` (line 176)
- `withAssignee` (line 188)
- `withTimeLogged` (line 197)
- `withPriority` (line 206)
- `withTag` (line 215)
- `withWatcher` (line 226)


### PragmaModule.swift

- **Lines**: 396
- **Public Types**: 11
- **Public Functions**: 7


**Public Types:**
- `enum PragmaModule` (line 27)
- `struct WorkItemId` (line 51)
- `enum WorkItemType` (line 96)
- `enum WorkPriority` (line 142)
- `enum StatusCategory` (line 180)
- `struct WorkflowStatus` (line 198)
- `struct WorkflowDefinition` (line 225)
- `struct WorkflowTransition` (line 300)
- `struct WorkItemOwnershipCheck` (line 325)
- `struct WorkflowTransitionCheck` (line 343)
- `enum PragmaError` (line 368)



**Public Functions:**
- `initialize` (static) (line 32)
- `validTransitions` (line 250)
- `isValidTransition` (line 258)
- `appliesTo` (line 332)
- `evaluate` (line 336)
- `appliesTo` (line 350)
- `evaluate` (line 354)


### Services/AutomationService.swift

- **Lines**: 539
- **Public Types**: 10
- **Public Functions**: 19


**Public Types:**
- `struct AutomationRule` (line 257)
- `struct AutomationTrigger` (line 297)
- `enum WorkEventType` (line 340)
- `struct WorkEvent` (line 358)
- `struct AutomationCondition` (line 389)
- `enum ConditionOperator` (line 401)
- `struct AutomationAction` (line 415)
- `enum PragmaActionType` (line 446)
- `struct AutomationExecution` (line 462)
- `enum AutomationError` (line 482)



**Public Functions:**
- `registerRule` (line 35)
- `removeRule` (line 40)
- `listRules` (line 45)
- `getRule` (line 50)
- `setRuleEnabled` (line 55)
- `processEvent` (line 64)
- `getExecutions` (line 240)
- `getRecentExecutions` (line 249)
- `matches` (line 307)
- `onStatusChange` (static) (line 320)
- `onCreated` (static) (line 324)
- `setStatus` (static) (line 425)
- `assignTo` (static) (line 429)
- `addTag` (static) (line 433)
- `addComment` (static) (line 437)
- `setPriority` (static) (line 441)
- `autoAssignBugs` (static) (line 506)
- `tagUrgentCritical` (static) (line 517)
- `celebrateDone` (static) (line 528)


### Services/ViewService.swift

- **Lines**: 538
- **Public Types**: 10
- **Public Functions**: 10


**Public Types:**
- `struct ListView` (line 294)
- `struct BoardView` (line 304)
- `struct BoardColumn` (line 313)
- `struct TimelineView` (line 322)
- `struct TimelineItem` (line 335)
- `struct DashboardView` (line 343)
- `struct TaskFilter` (line 359)
- `enum TaskSort` (line 461)
- `struct SavedView` (line 492)
- `enum SavedViewType` (line 532)



**Public Functions:**
- `listView` (line 30)
- `myTasksView` (line 65)
- `boardView` (line 80)
- `timelineView` (line 134)
- `dashboardView` (line 188)
- `saveView` (line 244)
- `getSavedView` (line 249)
- `listSavedViews` (line 254)
- `deleteSavedView` (line 259)
- `matches` (line 402)


### Services/WorkService.swift

- **Lines**: 557
- **Public Types**: 0
- **Public Functions**: 18




**Public Functions:**
- `registerWorkflow` (line 38)
- `getWorkflow` (line 43)
- `listWorkflows` (line 48)
- `createProject` (line 55)
- `getProject` (line 112)
- `getProject` (line 117)
- `updateProject` (line 126)
- `createTask` (line 170)
- `getTask` (line 252)
- `getTask` (line 257)
- `transitionTask` (line 266)
- `assignTask` (line 351)
- `updateTask` (line 409)
- `logWork` (line 444)
- `addComment` (line 473)
- `getProjectTasks` (line 514)
- `getTasksAssignedTo` (line 530)
- `getOverdueTasks` (line 544)



Note: All Actor-bound coordination in this module is being deprecated in favor of **Saturated Missions**.
