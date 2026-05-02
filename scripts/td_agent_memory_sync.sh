#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/td_agent_memory_sync.sh --issue <td-id> --source <agent> [--file path]
  scripts/td_agent_memory_sync.sh --template

Posts a curated, task-scoped agent memory summary into a TD issue.

This is intentionally not a raw memory dump. Input must be a short structured
summary containing at least one of these headings:
  DECISION:, BLOCKER:, FILES:, VERIFICATION:, NEXT:, UNCERTAIN:

Examples:
  gemini memory show latest | scripts/td_agent_memory_sync.sh --issue td-dbdb41 --source gemini
  scripts/td_agent_memory_sync.sh --issue td-dbdb41 --source copilot --file /tmp/copilot-summary.md
EOF
}

template() {
  cat <<'EOF'
DECISION:
- 

BLOCKER:
- 

FILES:
- 

VERIFICATION:
- 

NEXT:
- 

UNCERTAIN:
- 
EOF
}

issue_id=""
source_agent=""
input_file=""
max_bytes=8000

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --template)
      template
      exit 0
      ;;
    --issue)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "td_agent_memory_sync: --issue requires a TD issue id" >&2
        exit 2
      fi
      issue_id="$2"
      shift 2
      ;;
    --source)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "td_agent_memory_sync: --source requires an agent name" >&2
        exit 2
      fi
      source_agent="$2"
      shift 2
      ;;
    --file)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "td_agent_memory_sync: --file requires a path" >&2
        exit 2
      fi
      input_file="$2"
      shift 2
      ;;
    --max-bytes)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "td_agent_memory_sync: --max-bytes requires an integer" >&2
        exit 2
      fi
      max_bytes="$2"
      shift 2
      ;;
    *)
      echo "td_agent_memory_sync: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$issue_id" || -z "$source_agent" ]]; then
  usage >&2
  exit 2
fi

case "$source_agent" in
  gemini|copilot|codex|vibe|claude|cursor|other)
    ;;
  *)
    echo "td_agent_memory_sync: unsupported source '$source_agent'" >&2
    echo "Allowed sources: gemini, copilot, codex, vibe, claude, cursor, other" >&2
    exit 2
    ;;
esac

if ! command -v td >/dev/null 2>&1; then
  echo "td_agent_memory_sync: td command not found" >&2
  exit 127
fi

if [[ -n "$input_file" ]]; then
  if [[ ! -f "$input_file" ]]; then
    echo "td_agent_memory_sync: file not found: $input_file" >&2
    exit 2
  fi
  content="$(<"$input_file")"
else
  content="$(cat)"
fi

if [[ -z "${content//[[:space:]]/}" ]]; then
  echo "td_agent_memory_sync: refusing to sync empty memory summary" >&2
  exit 2
fi

byte_count="$(printf '%s' "$content" | wc -c | tr -d '[:space:]')"
if (( byte_count > max_bytes )); then
  echo "td_agent_memory_sync: refusing ${byte_count}-byte input; max is ${max_bytes}" >&2
  echo "Summarize into task-scoped decisions/blockers/files/verification/next steps first." >&2
  exit 2
fi

if ! grep -Eq '^(DECISION|BLOCKER|FILES|VERIFICATION|NEXT|UNCERTAIN):' <<<"$content"; then
  echo "td_agent_memory_sync: input must include at least one structured heading" >&2
  template >&2
  exit 2
fi

timestamp="$(date '+%Y-%m-%dT%H:%M:%S%z')"

td log "$issue_id" "$(cat <<EOF
AGENT_MEMORY_SYNC:
source: ${source_agent}
captured_at: ${timestamp}
policy: task-scoped curated summary; raw external memory intentionally omitted

${content}
EOF
)"
