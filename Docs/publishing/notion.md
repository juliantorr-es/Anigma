# Notion Publishing Doctrine

**Status**: Active
**Scope**: Presentation layer for Anigma task artifacts.

## Overview
Notion acts as a **presentation index** for task artifacts, not an evidence authority. All source-of-truth evidence (JSON, binary, logs) must reside in the Git repository or its associated build/diagnostic folders.

## Boundary Principles
1. **Separation of Concerns**: Diagnostic scripts (evidence collection) must have zero dependencies on Notion, MCP, or networking.
2. **Read-Only Publisher**: Notion pages should reflect the current state of Git, not vice-versa.
3. **No Network Bleed**: Harness execution must proceed perfectly without `NOTION_TOKEN` or connectivity.
4. **Non-Canonical View**: If Notion disagrees with a local proof artifact, the Git-stored file is the truth.

## Setup Requirements
1. **Internal Connection**: Create an [Internal Integration](https://www.notion.so/my-integrations) in your workspace.
2. **Database**: Create a target database in Notion with properties:
   - Name (title)
   - task_id (text)
   - status (select)
   - priority (select)
   - artifact_type (select)
   - proof_path (text)
   - source_path (text)
   - rendered_hash (text)
   - stale (checkbox)
   - last_published_at (date)
3. **Configuration**:
   - Share the database with your internal connection.
   - Set environment variables:
     - `export NOTION_TOKEN=...`
     - `export NOTION_DATABASE_ID=...`

## Limitations
- **Presentation-only**: The publisher supports a conservative Markdown-to-Notion block mapper. Rich features may be lost or rendered as plain text.
- **No OAuth**: Only manual Internal Integration tokens are supported.
- **Manual Sync**: Publishing is a manual, CLI-triggered process (`anigma_publish_notion.py`).
