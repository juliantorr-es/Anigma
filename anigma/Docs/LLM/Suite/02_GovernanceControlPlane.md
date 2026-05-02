# 02: Governance Control Plane: Implementation Detail

## Anigma Doctor
A unified CLI entry point (`anigma doctor`) that synchronizes the build state:
- **Build Hygiene**: Standardizes `swift build` and `swift test` flags (targeting only affected modules).
- **Graph Consistency**: Parses `swift package describe --type json` to build an adjacency list representing the actual effective compile graph.
- **Cycle Detection**: DFS traversal on the adjacency list. Cycle detection is non-negotiable: a cycle returns exit code 1 and prints the cyclic chain.

## Evidence Authority
- **Receipts**: Every agent action (patch, validation) is recorded in the task's log (`td log <id>`).
- **Proofs**: Evidence of structural consistency (cycle graph, export audit) must be committed to the `proofs/` directory before any P0 task is moved to review.
