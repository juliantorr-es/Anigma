#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/td_finish_or_block.sh review --issue <td-id> --summary <text>
  scripts/td_finish_or_block.sh block --issue <td-id> --blocker <td-id> --reason <text>
  scripts/td_finish_or_block.sh block --issue <td-id> --create-blocker-title <title> --reason <text> [--priority P0]

Enforces the agent finish/fail contract:
  - Finished implementation work must be handed off and submitted for review.
  - Failed implementation work must be linked to a known blocker or create one.

Examples:
  scripts/td_finish_or_block.sh review --issue td-abc123 --summary "Build passes for target X."
  scripts/td_finish_or_block.sh block --issue td-abc123 --blocker td-def456 --reason "Blocked by missing API."
  scripts/td_finish_or_block.sh block --issue td-abc123 --create-blocker-title "Fix missing API" --reason "Build fails because API is absent."
EOF
}

mode="${1:-}"
if [[ $# -gt 0 ]]; then
  shift
fi

issue_id=""
summary=""
reason=""
blocker_id=""
create_blocker_title=""
priority="P1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --issue)
      issue_id="${2:-}"
      shift 2
      ;;
    --summary)
      summary="${2:-}"
      shift 2
      ;;
    --reason)
      reason="${2:-}"
      shift 2
      ;;
    --blocker)
      blocker_id="${2:-}"
      shift 2
      ;;
    --create-blocker-title)
      create_blocker_title="${2:-}"
      shift 2
      ;;
    --priority)
      priority="${2:-}"
      shift 2
      ;;
    *)
      echo "td_finish_or_block: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v td >/dev/null 2>&1; then
  echo "td_finish_or_block: td command not found" >&2
  exit 127
fi

if [[ -z "$mode" || -z "$issue_id" ]]; then
  usage >&2
  exit 2
fi

case "$priority" in
  P0|P1|P2|P3|P4) ;;
  *)
    echo "td_finish_or_block: --priority must be P0, P1, P2, P3, or P4" >&2
    exit 2
    ;;
esac

case "$mode" in
  review)
    if [[ -z "$summary" ]]; then
      echo "td_finish_or_block: review requires --summary" >&2
      exit 2
    fi

    td handoff "$issue_id" \
      --done "$summary" \
      --remaining "Submitted for review; reviewer should validate acceptance criteria and evidence." \
      --decision "Implementation finished; moving immediately to review per agent workflow policy." \
      --uncertain "Reviewer may reject with specific findings if evidence is insufficient."
    td review "$issue_id" --reason "$summary"
    ;;
  block)
    if [[ -z "$reason" ]]; then
      echo "td_finish_or_block: block requires --reason" >&2
      exit 2
    fi

    if [[ -n "$blocker_id" && -n "$create_blocker_title" ]]; then
      echo "td_finish_or_block: use either --blocker or --create-blocker-title, not both" >&2
      exit 2
    fi

    if [[ -z "$blocker_id" ]]; then
      if [[ -z "$create_blocker_title" ]]; then
        echo "td_finish_or_block: block requires --blocker or --create-blocker-title" >&2
        exit 2
      fi

      create_output="$(td create "$create_blocker_title" \
        --type bug \
        --priority "$priority" \
        --labels blocker,agent-discovered \
        --description "$reason" \
        --blocks "$issue_id" \
        --acceptance "The blocker is resolved with concrete implementation evidence, verification output, and a TD handoff.")"
      printf '%s\n' "$create_output"
      blocker_id="$(printf '%s\n' "$create_output" | awk '/^CREATED / {print $2; exit}')"

      if [[ -z "$blocker_id" ]]; then
        echo "td_finish_or_block: could not parse created blocker id" >&2
        exit 1
      fi
    else
      td dep add "$issue_id" "$blocker_id"
    fi

    td log "$issue_id" "BLOCKED: ${reason} Blocker: ${blocker_id}"
    td block "$issue_id" --reason "$reason"
    ;;
  *)
    echo "td_finish_or_block: mode must be review or block" >&2
    usage >&2
    exit 2
    ;;
esac
