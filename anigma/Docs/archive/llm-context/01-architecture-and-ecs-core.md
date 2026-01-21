# Anigma: Architecture and ECS Core

Anigma is an ecosystem composed of three primary interconnected projects: Anigma Core, Harmonia, and Apertum Accessum, all built upon a foundational Entity-Component-System (ECS) architecture. (see Docs/architecture/overview.md)

## Overall Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      App Shells                             │
│  Ergasterion (IDE)  │  Daemon  │  CLI Tools  │  Web Admin   │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                    Domain Modules                           │
│  Harmonia   │  Diaplasion  │  Accessum  │  Outlineum        │
│  (dev/code) │  (alt-media) │  (client)  │  (art/zines)      │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│              AnigmaCore & DatabaseCore                      │
│  ECS: World, Entity, Component, System                      │
│  Jobs: Job, Workflow, Scheduler                             │
│  Shared: FileComponent, QAComponent, MetadataComponent      │
│  Utilities: Logging, Configuration, Errors                  │
│  DatabaseCore: Secure, thread-safe SQLite access            │
└─────────────────────────────────────────────────────────────┘
```
(from Docs/Overview.md, simplified and updated)

### Key Projects and Their Relations

*   **Anigma Core**: The foundational framework. Serves as the unifying ECS and job/pipeline core. Provides fundamental building blocks (`EntityId`, `Component`, `System`, `World`). Ensures consistent, modular approach. (see Docs/architecture/overview.md)
*   **Harmonia**: The AI Orchestration Brain. Intelligent backend managing AI-driven tasks, policies, and system state (session management, policy enforcement, multi-model routing, tiered memory, job queue). (see Docs/architecture/overview.md)
*   **Apertum Accessum**: The Accessible Client Face. User-facing macOS client focused on accessibility and compliance for alt-media and document processing. (see Docs/architecture/overview.md)
*   **Interconnection**: Anigma Core provides the foundational ECS. Harmonia processes documents and orchestrates AI for Apertum Accessum, which offers the accessible UI. (see Docs/architecture/overview.md)

## Entity-Component-System (ECS) Concepts

Anigma uses ECS for modularity, scalability, and maintainability. (see Docs/concepts/ecs.md)

*   **Entities**: Unique identifiers representing "things" (e.g., `Document`, `User`, `Job`). Entities have no data or behavior themselves, just an ID.
*   **Components**: Pure data containers describing aspects of an Entity (e.g., `FileComponent(path: "...")`, `TitleComponent(text: "...")`). Components contain only data, no behavior.
*   **Systems**: Logic that operates on Entities possessing specific Components. Systems are stateless, query-driven, and decoupled. (e.g., `OcrProcessingSystem` processes `DocumentEntities` with `FileComponent`).
*   **World**: The central object (an actor for thread-safety) that manages all Entities, their attached Components, and System execution. (see Docs/concepts/ecs.md)

## World, Job, and Workflow Model (High-Level)

*   **World**: An actor for thread-safe entity/component management. (see ADR/0001-single-ecs-in-anigmacore.md)
*   **Job**: A unit of work (e.g., `Job` struct with `id`, `typeId`, `inputRefs`, `outputRefs`, `status`, `priority`). (see ADR/0002-job-and-workflow-model.md)
*   **Workflow**: Defines a sequence of `System` execution for a specific `Job` type. Modules register workflows, and the core executes them. (see ADR/0002-job-and-workflow-model.md)
*   **Scheduler**: An actor-based component managing job queues, priority ordering, and retry logic. (see ADR/0002-job-and-workflow-model.md)
*   **Unified Model**: AnigmaCore provides the single ECS and job/workflow implementation for consistency, interoperability, and maintenance. (see ADR/0001-single-ecs-in-anigmacore.md, ADR/0002-job-and-workflow-model.md)
