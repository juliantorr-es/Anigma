# Rig Notifications

Rig supports optional macOS notifications as a derived user-facing sink for final command results.

## Doctrine

- Notifications are opt-in.
- Notifications are not canonical state.
- Notifications do not replace result JSON, JSONL events, or proofs.
- Notification failures must not fail the Rig command.
- Long-running commands should notify from the final result state, not per-step chatter.

## Backends

### `osascript`

- Default macOS backend when notification delivery is requested.
- Uses AppleScript `display notification`.
- No shell execution.
- Title, subtitle, and message are sanitized before dispatch.

### `terminal-notifier`

- Optional backend if installed.
- Detected with `shutil.which("terminal-notifier")`.
- Not required.

### `none`

- Explicit no-op backend.

## Commands

- `python3 scripts/rig.py notify test`
- `python3 scripts/rig.py notify status`
- `python3 scripts/rig.py notify send --title "Rig" --message "Test notification"`

## Global Flags

- `--notify`
- `--notify-on finish|failure|known-blocked|blocked|ready|never`
- `--notify-backend osascript|terminal-notifier|none`

## Result Fields

Final Rig result JSON includes:

- `notification_requested`
- `notification_backend`
- `notification_status`
- `notification_error`

## Status Mapping

- `finish` notifies on `passed`, `failed`, `known_blocked`, `blocked`, and `ready_to_commit`
- `failure` notifies on `failed`
- `known-blocked` notifies on `known_blocked`
- `blocked` notifies on `blocked`
- `ready` notifies on `ready_to_commit`

## Recommended Use

Use notifications for:

- long-running pipeline runs
- final review/session bundles
- known-blocked tasks
- ready-to-commit states

Do not use notifications for:

- every step
- CI automation that must stay silent
- canonical workflow decisions
