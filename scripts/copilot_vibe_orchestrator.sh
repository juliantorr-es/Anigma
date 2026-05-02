#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$ROOT_DIR/.codex-orch/copilot-vibe"
COPILOT_BIN="${COPILOT_BIN:-$(command -v copilot || true)}"
VIBE_BIN="${VIBE_BIN:-$(command -v vibe || true)}"
COPILOT_SESSION_STATE_DIR="${COPILOT_SESSION_STATE_DIR:-$HOME/.copilot/session-state}"
COPILOT_MODEL="${COPILOT_MODEL:-gpt-5.3-codex}"
VIBE_AGENT="${VIBE_AGENT:-default}"
MAX_TURNS="${MAX_TURNS:-10}"

SESSION_INFO_FILE="$WORK_DIR/session_info.env"
IMPLEMENT_PROMPT_FILE="$WORK_DIR/copilot_implement_prompt.txt"
REVIEW_PROMPT_FILE="$WORK_DIR/vibe_review_prompt.txt"
APPLY_PROMPT_FILE="$WORK_DIR/copilot_apply_review_prompt.txt"
REVIEW_REPORT_FILE="$WORK_DIR/vibe_review_report.txt"
COPILOT_LOG_FILE="$WORK_DIR/copilot.log"
VIBE_LOG_FILE="$WORK_DIR/vibe.log"
STATUS_FILE="$WORK_DIR/git_status.txt"
DIFF_STAT_FILE="$WORK_DIR/git_diff_stat.txt"
DIFF_FILE="$WORK_DIR/git_diff.patch"

usage() {
  cat <<'EOF'
Usage:
  scripts/copilot_vibe_orchestrator.sh status
  scripts/copilot_vibe_orchestrator.sh implement "task request"
  scripts/copilot_vibe_orchestrator.sh review
  scripts/copilot_vibe_orchestrator.sh apply-review
  scripts/copilot_vibe_orchestrator.sh all "task request"

Modes:
  status        Show the latest Copilot roadmap session detected for this repo.
  implement     Resume that Copilot session and execute a roadmap-constrained task.
  review        Ask Vibe to critique the current diff against the roadmap.
  apply-review  Ask Copilot to apply justified fixes from the latest Vibe review.
  all           Run implement, review, then apply-review.

Environment:
  COPILOT_BIN                 Path to Copilot CLI.
  VIBE_BIN                    Path to Vibe CLI.
  COPILOT_SESSION_STATE_DIR   Copilot session-state directory.
  COPILOT_MODEL               Copilot model (default: gpt-5.3-codex).
  VIBE_AGENT                  Vibe agent (default: default).
  MAX_TURNS                   Max Vibe turns in programmatic mode (default: 10).
  COPILOT_SESSION_ID          Force a specific Copilot session id.
EOF
}

ensure_requirements() {
  mkdir -p "$WORK_DIR"

  if [[ -z "$COPILOT_BIN" || ! -x "$COPILOT_BIN" ]]; then
    echo "error: Copilot CLI not found. Set COPILOT_BIN or install 'copilot'." >&2
    exit 1
  fi

  if [[ -z "$VIBE_BIN" || ! -x "$VIBE_BIN" ]]; then
    echo "error: Vibe CLI not found. Set VIBE_BIN or install 'vibe'." >&2
    exit 1
  fi

  if [[ ! -d "$COPILOT_SESSION_STATE_DIR" ]]; then
    echo "error: Copilot session-state directory not found: $COPILOT_SESSION_STATE_DIR" >&2
    exit 1
  fi
}

load_session_info() {
  if [[ ! -f "$SESSION_INFO_FILE" ]]; then
    detect_latest_session >/dev/null
  fi

  # shellcheck disable=SC1090
  source "$SESSION_INFO_FILE"
}

detect_latest_session() {
  local forced_session_id="${COPILOT_SESSION_ID:-}"
  local best_line=""

  if [[ -n "$forced_session_id" ]]; then
    local forced_dir="$COPILOT_SESSION_STATE_DIR/$forced_session_id"
    if [[ ! -f "$forced_dir/workspace.yaml" || ! -f "$forced_dir/plan.md" ]]; then
      echo "error: forced COPILOT_SESSION_ID=$forced_session_id does not have workspace.yaml + plan.md" >&2
      exit 1
    fi
    best_line="$(session_descriptor "$forced_dir")"
  else
    local session_dir line
    while IFS= read -r -d '' session_dir; do
      line="$(session_descriptor "$session_dir" || true)"
      [[ -z "$line" ]] && continue
      if [[ -z "$best_line" || "$line" > "$best_line" ]]; then
        best_line="$line"
      fi
    done < <(find "$COPILOT_SESSION_STATE_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  if [[ -z "$best_line" ]]; then
    echo "error: no Copilot session with plan.md found for repo $ROOT_DIR" >&2
    exit 1
  fi

  IFS=$'\t' read -r updated_at session_id session_dir summary branch plan_path <<<"$best_line"
  cat >"$SESSION_INFO_FILE" <<EOF
SESSION_ID='$session_id'
SESSION_DIR='$session_dir'
UPDATED_AT='$updated_at'
SUMMARY='${summary//\'/\'\"\'\"\'}'
BRANCH='${branch//\'/\'\"\'\"\'}'
PLAN_PATH='$plan_path'
EOF

  printf '%s\n' "$best_line"
}

session_descriptor() {
  local session_dir="$1"
  local workspace="$session_dir/workspace.yaml"
  local plan_path="$session_dir/plan.md"

  [[ -f "$workspace" && -f "$plan_path" ]] || return 0

  local cwd git_root session_id updated_at summary branch
  cwd="$(grep -E '^cwd:' "$workspace" | head -1 | sed 's/^cwd: //')"
  git_root="$(grep -E '^git_root:' "$workspace" | head -1 | sed 's/^git_root: //')"
  session_id="$(grep -E '^id:' "$workspace" | head -1 | sed 's/^id: //')"
  updated_at="$(grep -E '^updated_at:' "$workspace" | head -1 | sed 's/^updated_at: //')"
  summary="$(grep -E '^summary:' "$workspace" | head -1 | sed 's/^summary: //; s/^"//; s/"$//')"
  branch="$(grep -E '^branch:' "$workspace" | head -1 | sed 's/^branch: //')"

  if [[ "$cwd" != "$ROOT_DIR" && "$git_root" != "$ROOT_DIR" ]]; then
    return 0
  fi

  [[ -n "$updated_at" && -n "$session_id" ]] || return 0
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$updated_at" "$session_id" "$session_dir" "$summary" "$branch" "$plan_path"
}

print_status() {
  load_session_info
  cat <<EOF
Copilot roadmap session
  session_id: $SESSION_ID
  updated_at: $UPDATED_AT
  branch: ${BRANCH:-unknown}
  summary: ${SUMMARY:-unknown}
  plan: $PLAN_PATH
EOF
}

capture_diff_context() {
  git -C "$ROOT_DIR" status --short >"$STATUS_FILE"
  git -C "$ROOT_DIR" diff --stat >"$DIFF_STAT_FILE"
  git -C "$ROOT_DIR" diff --no-ext-diff --unified=0 >"$DIFF_FILE"
}

require_diff() {
  capture_diff_context
  if [[ ! -s "$DIFF_FILE" ]]; then
    echo "error: no working tree diff found to review." >&2
    echo "hint: run 'implement' first or make changes before 'review'." >&2
    exit 1
  fi
}

run_copilot_prompt() {
  local prompt_file="$1"
  : >"$COPILOT_LOG_FILE"
  "$COPILOT_BIN" \
    --resume "$SESSION_ID" \
    -p "$(cat "$prompt_file")" \
    --model "$COPILOT_MODEL" \
    --allow-all-tools \
    --allow-all-paths \
    --allow-all-urls \
    --no-ask-user \
    --stream off \
    -s | tee "$COPILOT_LOG_FILE"
}

run_vibe_prompt() {
  local prompt_file="$1"
  : >"$VIBE_LOG_FILE"
  "$VIBE_BIN" \
    -p "$(cat "$prompt_file")" \
    --agent "$VIBE_AGENT" \
    --max-turns "$MAX_TURNS" \
    --output text | tee "$VIBE_LOG_FILE"
}

write_implement_prompt() {
  local task_request="$1"
  cat >"$IMPLEMENT_PROMPT_FILE" <<EOF
You are continuing the existing roadmap session for repository $ROOT_DIR.

Roadmap source of truth:
- Resume session: $SESSION_ID
- Read and follow the roadmap plan at: $PLAN_PATH

Task request:
$task_request

Required behavior:
1. Read the roadmap plan before making changes.
2. Read anigma/Docs/LLM/AGENT-SKILL-PACK.md and use the relevant skill.
3. Keep the implementation aligned with TD and the roadmap; TD wins if they disagree.
4. Prefer the smallest focused change that advances the task.
5. Respect repository instructions and existing architecture constraints.
6. After editing, run a focused validation command if appropriate.

Output format:
- Roadmap alignment: which roadmap todo/track this advances, or why it is consistent.
- Changes made
- Validation
- Residual risks
EOF
}

write_review_prompt() {
  cat >"$REVIEW_PROMPT_FILE" <<EOF
Review the current git diff in repository $ROOT_DIR.

Roadmap source of truth:
- Copilot plan file: $PLAN_PATH

Artifacts to read before responding:
- Roadmap plan: $PLAN_PATH
- Agent skill pack: $ROOT_DIR/anigma/Docs/LLM/AGENT-SKILL-PACK.md
- Git status: $STATUS_FILE
- Git diff stat: $DIFF_STAT_FILE
- Git diff patch: $DIFF_FILE

Your job:
- Critique whether the diff follows the roadmap.
- Critique code quality, correctness, maintainability, logging, tests, and guardrails where relevant.
- Be strict. Call out issues clearly.
- If the diff is good enough, say so explicitly.

Output format:
1. Verdict
2. Findings
3. Suggested fixes

If there are no material issues, write exactly:
NO_CHANGES_NEEDED
and then one short paragraph explaining why.
EOF
}

write_apply_review_prompt() {
  cat >"$APPLY_PROMPT_FILE" <<EOF
You are continuing the existing roadmap session for repository $ROOT_DIR.

Roadmap source of truth:
- Resume session: $SESSION_ID
- Roadmap plan: $PLAN_PATH

Review feedback to consider:
- $REVIEW_REPORT_FILE

Required behavior:
1. Read the roadmap plan and the Vibe review.
2. Read anigma/Docs/LLM/AGENT-SKILL-PACK.md and use the focused implementation/review-fix workflow.
3. Apply only the justified fixes that improve TD/roadmap alignment or code quality.
4. Ignore any review suggestion that would conflict with TD, the roadmap, or create unnecessary churn.
5. Run one focused validation command if appropriate.

Output format:
- Applied review items
- Skipped review items and why
- Validation
- Remaining risks
EOF
}

implement() {
  local task_request="$1"
  load_session_info
  write_implement_prompt "$task_request"
  run_copilot_prompt "$IMPLEMENT_PROMPT_FILE"
}

review() {
  load_session_info
  require_diff
  write_review_prompt
  run_vibe_prompt "$REVIEW_PROMPT_FILE" | tee "$REVIEW_REPORT_FILE"
}

apply_review() {
  load_session_info
  if [[ ! -f "$REVIEW_REPORT_FILE" ]]; then
    echo "error: no Vibe review report found at $REVIEW_REPORT_FILE" >&2
    exit 1
  fi

  if grep -qx 'NO_CHANGES_NEEDED' "$REVIEW_REPORT_FILE"; then
    echo "Vibe review reports no material changes needed."
    return 0
  fi

  write_apply_review_prompt
  run_copilot_prompt "$APPLY_PROMPT_FILE"
}

main() {
  ensure_requirements

  local cmd="${1:-status}"
  case "$cmd" in
    status)
      detect_latest_session >/dev/null
      print_status
      ;;
    implement)
      shift
      [[ $# -gt 0 ]] || { echo "error: implement requires a task request." >&2; usage; exit 1; }
      detect_latest_session >/dev/null
      implement "$*"
      ;;
    review)
      shift
      detect_latest_session >/dev/null
      review
      ;;
    apply-review)
      shift
      detect_latest_session >/dev/null
      apply_review
      ;;
    all)
      shift
      [[ $# -gt 0 ]] || { echo "error: all requires a task request." >&2; usage; exit 1; }
      detect_latest_session >/dev/null
      implement "$*"
      review
      apply_review
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "error: unknown subcommand '$cmd'" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
