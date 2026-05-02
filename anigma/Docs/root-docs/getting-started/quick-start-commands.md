---
title: "Quick Start Commands"
description: "Documentation for Quick Start Commands"
audience: ["developers"]
complexity: "beginner"
estimated_time: "5 minutes"
status: "active"
last_updated: "2026-05-01"
---

# Quick Start Commands

The Anigma system has been consolidated into a single deep module: the `anigmad` daemon. This provides a single, high-leverage interface for all operations.

## Core Daemon Management

These commands manage the lifecycle of the `anigmad` background service and its warm-pooled SubprocessWorkers.

```bash
anigmad start         # Start the daemon and initialize worker pools
anigmad status        # View health and worker pool saturation
anigmad stop          # Gracefully spin down the daemon and workers
```

## AI Agent Orchestration (Formerly `harmonia`)

The agent orchestration logic has been pulled behind the `anigmad cli` boundary.

```bash
anigmad cli run "analyze logs"    # Run a natural language workflow
anigmad cli agents                # List available registered agents
anigmad cli chat                  # Open an interactive CLI session
```

## Verification (Formerly `AnigmaDaemonVerifier`)

Validation commands are now exposed as subcommands, ensuring they execute against the current running daemon's configuration.

```bash
anigmad verify-chain              # Run the full cryptographic evidence verification
anigmad verify-chain --quick      # Run a quick signature check
```

## Advanced Subprocess Worker Controls

To manually query the state of the isolated workers behind the `SubprocessWorker` seam:

```bash
anigmad workers list              # Show all warm/active subprocesses
anigmad workers kill <id>         # Force kill a specific isolated worker
```
