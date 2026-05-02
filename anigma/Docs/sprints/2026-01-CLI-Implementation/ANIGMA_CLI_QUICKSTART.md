> Historical status snapshot. This file reflects the state observed on 2026-04-21 and is not the source of truth for current status.
>
> Source of truth:
> - `td`
> - `anigma/current_build_status.txt`
> - `anigma/build_phase3_logs/`


# anigma-cli Quick Start Guide

**Version**: 1.0.0  
**Status**: Production Ready

## Installation

```bash
# Build
swift build -c release --product anigma-cli

# Install
cp .build/release/anigma-cli /usr/local/bin/
```

## First Steps

### 1. Check Status
```bash
anigma-cli status current
```

### 2. Configure Security
```bash
# Allow your project directory
anigma-cli policy allow-path ~/projects/myapp

# Trust anigma-mcp server
anigma-cli policy trust anigma-mcp --level trusted
```

### 3. Index Your Project
```bash
anigma-cli index add ~/projects/myapp
```

### 4. Acquire Worktree
```bash
anigma-cli worktree acquire ~/projects/myapp
```

### 5. Create a Run
```bash
anigma-cli runs create "Implement feature X"
```

## Common Commands

### Search Code
```bash
anigma-cli index search "function handleSubmit"
```

### List Runs
```bash
anigma-cli runs list --status running
```

### Execute Tools
```bash
anigma-cli tools exec read_file --path src/main.swift
```

### Check Policy
```bash
anigma-cli policy check --operation write /path/to/file
```

## Security Defaults

- **Default Action**: Require approval
- **Denied Paths**: `/etc`, `/System`, `~/.ssh`
- **Allowed Commands**: `git`, `swift`, `cat`, `ls`, `grep`
- **Max File Size**: 10MB
- **Loop Limit**: 50 steps, 600s max

## MCP Trust Levels

- `untrusted`: No operations
- `read_only`: Safe reads only
- `restricted`: Temporary writes (24h)
- `trusted`: All operations

## Get Help

```bash
# General help
anigma-cli --help

# Command help
anigma-cli <command> --help

# Example
anigma-cli policy --help
```

## Testing

```bash
# Run all tests
swift test

# Validate compliance
./Scripts/validate_surface_compliance.sh
```

## Configuration

Default location: `~/.anigma-cli/`

Files:
- `anigma.db` - Main database
- `policy.json` - Security policies
- `.lock` - Lock file

## Documentation

- `ANIGMA_CLI_HANDOFF.md` - Complete handoff
- `CLI_COMPLETE_STATUS.md` - Full status
- `CLI_ARCHITECTURE_REINFORCEMENT.md` - Architecture

## Support

Run compliance check:
```bash
./Scripts/validate_surface_compliance.sh
```

Check status:
```bash
anigma-cli status current
```

---

**Happy Coding!** 🚀
