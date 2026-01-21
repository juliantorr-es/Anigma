# DoctrineCLI

**Architectural doctrine debt observability and management.**

`DoctrineCLI` (aliased as `doctrine`) is a specialized tool for tracking, inspecting, and resolving violations of the platform's architectural doctrines. It provides visibility into technical debt and ensures that the repository remains in compliance with defined standards.

## Role in the Ecosystem

While `DoctrineCore` defines the rules and `GovernanceCore` enforces them at runtime, `DoctrineCLI` provides the human-facing interface to the recorded violations. it allows developers to audit the "doctrine debt" of the repository.

## Usage

### Check Debt Status
Get a high-level summary of all active violations, severity breakdown, and top violating files.
```bash
swift run doctrine status
```

### List Violations
List detailed information about specific violations, with support for filtering.
```bash
swift run doctrine violations --severity critical --limit 10
```

### Rule Statistics
Show which rules are most frequently violated and their resolution rates.
```bash
swift run doctrine rules
```

### Resolve a Violation
Mark a recorded violation as resolved with a justification.
```bash
swift run doctrine resolve <violation-id> "Fixed in PR #123"
```

## Configuration

| Option | Shorthand | Description | Default |
|--------|-----------|-------------|---------|
| `--db-path`| `-d` | Path to the doctrine violation database (SQLite). | `./harmonia_harness.sqlite` |
| `--limit` | `-l` | Maximum number of results to display. | 20 |
| `--severity`| `-s` | Filter by severity (notice, warning, error, critical). | N/A |

## Database Schema

The tool interacts with the `doctrine_violations` table, which typically includes:
- `id`: Unique identifier for the violation.
- `rule_id`: The ID of the violated doctrine rule.
- `file_path`: (Optional) Source file where the violation was detected.
- `severity`: Severity level at the time of detection.
- `context`: Additional context or evidence for the violation.

## Thread Safety

- Reads and writes to the SQLite database are handled using thread-safe patterns.
- designed for local developer use and CI reporting.

## Dependencies

- **HarmoniaModule**: Shared database logic.
- **DoctrineCore**: Rule and severity definitions.
- **ArgumentParser**: CLI interface.
- **SQLite3**: For direct data access.

## License

Part of the Anigma project. See LICENSE for details.
