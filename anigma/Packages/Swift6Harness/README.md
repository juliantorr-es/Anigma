# Swift6Harness

**Low-level diagnostic harness for Swift 6 migration and trust experiments.**

`Swift6Harness` is a specialized, dependency-minimal tool designed to bypass complex CLI layers and directly inspect the repository's governance and trust substrate. It is primarily used to monitor the progress of the Swift 6 migration and verify the "trust nervous system" during migration experiments.

## Role in the Ecosystem

When the high-level `harmonia` CLI or complex modules are unavailable (e.g., during early migration stages), `Swift6Harness` provides a direct window into the `harmonia_harness.sqlite` database. It ensures that architectural decisions and trust scores remain visible and verifiable even during deep infrastructure updates.

## Usage

### Run the Harness
Inspect the current state of trust, governance, and migration tasks:
```bash
swift run swift6-harness
```

## Inspected Domains

The harness queries the local SQLite substrate and presents a consolidated view of:

1. **Trust State**: Current trust scores and tiers for all subjects (modules, actors).
2. **Governance Mode**: Verifies the active governance strategy (e.g., `governed` vs `scout`).
3. **Migration Tasks**: Tracks the status and priority of `swift6-migration` labeled tasks.
4. **Recent Security Events**: Lists the latest five security audit logs (CCTV) from the `security_events` table.

## Key Features

- **Dependency Minimal**: Uses only `Foundation` and `SQLite3` (C API) to ensure it can run even when other modules fail to compile.
- **Direct Database Access**: Bypasses the ECS and business logic layers for raw evidence inspection.
- **Experimental Support**: Specifically designed for "Phase 4C" trust experiments.

## Configuration

| Item | Path/Value |
|------|------------|
| Database Path | `./harmonia_harness.sqlite` |
| Default Subject | `swift6-migration` |

## Prerequisites

- **Database Initialization**: The `harmonia_harness.sqlite` must be prepared (e.g., via `prepare_trust_experiment.sh`).

## Dependencies

- **Foundation**: Basic types.
- **SQLite3**: C-based database connectivity.

## License

Part of the Anigma project. See LICENSE for details.
