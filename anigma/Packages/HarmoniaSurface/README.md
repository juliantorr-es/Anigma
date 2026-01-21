# HarmoniaSurface

**Smoke harness for system surface and ECS verification.**

`HarmoniaSurface` is a diagnostic executable designed to verify the core ECS surface area, session management, and request routing without requiring a full UI or network stack. It is primarily used during CI to pulse the system and ensure basic reactive loops are functional.

## Role in the Ecosystem

`HarmoniaSurface` acts as a "pulse check" for the repository. It proves that the `World` actor, systems, and components can be correctly initialized and updated within a deterministic environment.

## Usage

### Basic Verification
Run a single update tick to verify system stability:
```bash
swift run harmonia-surface
```

### Scenario Execution
Run specialized diagnostic scenarios (e.g., verifying ML backend slots):
```bash
swift run harmonia-surface --scenario ml-worker-backends --output results.json
```

### Multi-Tick Stress Test
Run multiple ECS update cycles:
```bash
swift run harmonia-surface --ticks 10
```

## Scenarios

### ml-worker-backends
Verifies the concurrency control and slot management for ML workers. It checks if backends (chat, reasoner, oracle) correctly manage their in-flight request limits and pressure levels.

## Configuration

| Option | Shorthand | Description | Default |
|--------|-----------|-------------|---------|
| `--ticks` | `-t` | Number of ECS update ticks to execute. | 1 |
| `--scenario`| | Specific diagnostic scenario to run. | N/A |
| `--output` | | Path to write scenario results (JSON). | N/A |

## Thread Safety

- Entirely actor-isolated via the `AnigmaCore.World` and `ConcurrencyController`.
- Designed for safe execution in highly concurrent CI environments.

## Dependencies

- **AnigmaCore**: ECS engine.
- **MLWorkerCommon**: Types for backend scenarios.
- **ArgumentParser**: CLI interface.

## License

Part of the Anigma project. See LICENSE for details.
