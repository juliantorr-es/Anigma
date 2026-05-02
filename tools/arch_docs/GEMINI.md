# Anigma Project Memory

## Project Context & Table of Contents
- [Anigma Core Documentation](anigma/Docs/LLM/GEMINI.md) — Detailed architecture, build commands, and conventions.

## Development Workflow
- **Task Management**: Always follow the 'td' task management workflow (`ready`, `start`, `log/heartbeat`, `handoff`, `finish`).
- **Codebase Analysis**: Always prefer local CLI tools (`rg`, `fd`, `just`, `sg`, `universal-ctags`, `sourcekitten`) for codebase analysis.
- **Context Retrieval**: Use `kb-query` for project-specific context.
- **Search Filtering**: Ignore build artifacts in all searches.
