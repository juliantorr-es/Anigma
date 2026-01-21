# SmokeTestRenderer

**Deterministic verification of intent routing and authority boundaries.**

`SmokeTestRenderer` is a diagnostic tool used to prove the security and correctness of the `AnigmaClientKit` and `AnigmaHostKit` interaction model. It simulates a "renderer" (client) attempting to perform actions against a "host" (authority), verifying that the host correctly enforces state transitions, snapshot integrity, and cryptographic boundaries.

## Role in the Ecosystem

This tool serves as the "source of truth" for how the client-host split should behave. It ensures that any changes to the intent routing logic do not introduce security regressions (like nonce reuse or stale snapshot attacks).

## Usage

### Run the Smoke Test
Execute the automated test scenario:
```bash
swift run smoke-test-renderer
```

## Verified Scenarios

The tool executes a preset sequence of interactions and validates the outcome for each:

1. **Initial State**: Verifies that the host can register a surface and issue a capability token.
2. **Schema Unreachable**: Proves that a client cannot execute an action that is not present in the current Presentation IR.
3. **Valid Intent**: Proves that a validly constructed intent, matching the IR snapshot, is accepted and signed by the host.
4. **Nonce Reuse (Replay)**: Proves that the host blocks attempts to replay a previously successful intent.
5. **Stale Snapshot**: Proves that the host blocks intents targeting an outdated IR snapshot.
6. **Scope Violation**: Proves that the host blocks actions that violate the actor's permission scope, even if they are present in the IR.

## Key Components Tested

- **AnigmaAuthority**: The host-side logic for intent validation and IR management.
- **AnigmaClient**: The client-side SDK for submitting intents.
- **ActionIntent**: The cryptographic container for user actions.
- **SnapshotID**: The deterministic identifier for IR states.

## Dependencies

- **AnigmaClientKit**: Client-side SDK.
- **AnigmaHostKit**: Host-side authority.
- **ContractsCore**: Shared intent and IR models.

## License

Part of the Anigma project. See LICENSE for details.
