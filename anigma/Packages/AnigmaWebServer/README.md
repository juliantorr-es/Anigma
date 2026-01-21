# AnigmaWebServer

**Cathedral evidence-enforced web service for coordinate execution.**

`AnigmaWebServer` is a high-integrity web service built on Vapor that implements the "Single Anigma Computer" architecture. It acts as a thin, evidence-validated wrapper around the `CathedralModule`, ensuring that all coordination requests are backed by cryptographic evidence before being processed.

## Role in the Ecosystem

This service provides the remote interface for the Anigma platform. Unlike traditional web servers, it does not allow direct access to raw ML operations or data. Every request must pass through the `EvidenceEnforcementMiddleware`, which validates that sufficient evidence exists to justify the requested operation.

## Key Features

- **Strict Evidence Layer**: Prevents any operation from proceeding without verifiable evidence.
- **Plan-Based Execution**: Uses `PlanCompiler` to generate evidence-backed execution plans.
- **Execution Leases**: Implements short-lived, evidence-bound leases for execution integrity.
- **Court-Safe Bundles**: Provides a secure export mechanism for evidence chains and artifacts.
- **Sandboxed ML**: Raw ML operations are completely inaccessible from the web layer for security.

## Core API Endpoints

### `POST /api/v1/plan/submit`
Submits a coordination request. Returns an accepted plan or rejects it if evidence is insufficient.

### `GET /api/v1/plan/:id/inspect`
Verified the integrity of a generated plan and its evidence dependencies.

### `POST /api/v1/plan/:id/execute`
Executes an accepted plan and binds the output to the existing evidence chain.

### `POST /api/v1/bundle/export`
Generates a court-safe evidence bundle for a specific time range and reason.

## Configuration

| Environment Variable | Description |
|----------------------|-------------|
| `PORT` | Listening port for the Vapor application (default: 8080). |
| `DATABASE_URL` | Connection string for the underlying SQLite evidence store. |

## Thread Safety

- Built on Vapor's `EventLoop` and Swift Concurrency (`async/await`).
- All stateful operations are handled by the `DatabaseActor` or `EvidenceSubstrate`.

## Dependencies

- **Vapor**: Web framework.
- **CathedralModule**: Evidence enforcement and plan generation.
- **HarmoniaModule**: Shared logic.
- **DatabaseCore**: Persistent storage.
- **AnigmaCore**: Basic infrastructure.

## License

Part of the Anigma project. See LICENSE for details.
