#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANIGMA_DIR="$ROOT_DIR/anigma"
ORCH_DIR="$ROOT_DIR/.codex-orch/harmonia"
BUILD_LOG="$ORCH_DIR/harmonia_build_j1.log"
ERRORS_FILE="$ORCH_DIR/top50_errors.txt"
CLAUDE_BATCH="$ORCH_DIR/batch_claude.txt"
GEMINI_BATCH="$ORCH_DIR/batch_gemini.txt"
COPILOT_BATCH="$ORCH_DIR/batch_copilot.txt"
VIBE_BATCH="$ORCH_DIR/batch_vibe.txt"
CLAUDE_LOG="$ORCH_DIR/agent_claude.log"
GEMINI_LOG="$ORCH_DIR/agent_gemini.log"
COPILOT_LOG="$ORCH_DIR/agent_copilot.log"
VIBE_LOG="$ORCH_DIR/agent_vibe.log"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-420}"

usage() {
  cat <<'EOF'
Usage:
  scripts/harmonia_orchestrator.sh [all|build-errors|split-errors|dispatch]

Subcommands:
  build-errors   Run clean single-thread Harmonia build and extract top 50 real errors
  split-errors   Split top 50 errors into non-overlapping file batches per agent
  dispatch       Dispatch batches to claude/gemini/copilot/vibe with watchdog timeout
  all            Run build-errors, split-errors, then dispatch

Environment:
  TIMEOUT_SECONDS  Watchdog timeout per agent process (default: 420)
EOF
}

ensure_dirs() {
  mkdir -p "$ORCH_DIR"
}

build_errors() {
  ensure_dirs
  echo "[orchestrator] running: swift build -j 1 --target HarmoniaModule"
  (
    cd "$ANIGMA_DIR"
    swift build -j 1 --target HarmoniaModule
  ) >"$BUILD_LOG" 2>&1 || true

  awk '
    $0 ~ /^\/.*:[0-9]+(:[0-9]+)?: error: / &&
    $0 !~ /\/\.build\// &&
    $0 !~ /\/checkouts\//
    { print }
  ' "$BUILD_LOG" | awk '!seen[$0]++' | head -n 50 >"$ERRORS_FILE"

  local count
  count="$(wc -l <"$ERRORS_FILE" | tr -d ' ')"
  echo "[orchestrator] extracted $count errors to $ERRORS_FILE"
}

split_errors() {
  ensure_dirs
  : >"$CLAUDE_BATCH"
  : >"$GEMINI_BATCH"
  : >"$COPILOT_BATCH"
  : >"$VIBE_BATCH"

  if [[ ! -s "$ERRORS_FILE" ]]; then
    echo "[orchestrator] no errors found in $ERRORS_FILE"
    return 0
  fi

  local -a agents=("claude" "gemini" "copilot" "vibe")
  local next_agent_idx=0
  declare -A file_owner=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local file
    file="$(sed -E 's/^([^:]+):[0-9]+(:[0-9]+)?: error:.*/\1/' <<<"$line")"
    if [[ -z "${file_owner[$file]+x}" ]]; then
      file_owner["$file"]="${agents[$next_agent_idx]}"
      next_agent_idx=$(( (next_agent_idx + 1) % 4 ))
    fi
    case "${file_owner[$file]}" in
      claude)  echo "$line" >>"$CLAUDE_BATCH" ;;
      gemini)  echo "$line" >>"$GEMINI_BATCH" ;;
      copilot) echo "$line" >>"$COPILOT_BATCH" ;;
      vibe)    echo "$line" >>"$VIBE_BATCH" ;;
    esac
  done <"$ERRORS_FILE"

  echo "[orchestrator] batch sizes:"
  echo "  claude : $(wc -l <"$CLAUDE_BATCH" | tr -d ' ')"
  echo "  gemini : $(wc -l <"$GEMINI_BATCH" | tr -d ' ')"
  echo "  copilot: $(wc -l <"$COPILOT_BATCH" | tr -d ' ')"
  echo "  vibe   : $(wc -l <"$VIBE_BATCH" | tr -d ' ')"
}

watch_processes() {
  local p_claude="$1" p_gemini="$2" p_copilot="$3" p_vibe="$4"
  local start now elapsed
  start="$(date +%s)"

  while true; do
    local alive=0
    for p in "$p_claude" "$p_gemini" "$p_copilot" "$p_vibe"; do
      [[ "$p" -eq 0 ]] && continue
      if kill -0 "$p" 2>/dev/null; then
        alive=1
      fi
    done
    [[ "$alive" -eq 0 ]] && break

    now="$(date +%s)"
    elapsed=$((now - start))
    if (( elapsed >= TIMEOUT_SECONDS )); then
      echo "[orchestrator] timeout reached (${TIMEOUT_SECONDS}s); terminating remaining agents"
      for p in "$p_claude" "$p_gemini" "$p_copilot" "$p_vibe"; do
        [[ "$p" -eq 0 ]] && continue
        kill "$p" 2>/dev/null || true
      done
      break
    fi
    sleep 2
  done
}

dispatch() {
  ensure_dirs
  if [[ ! -s "$ERRORS_FILE" ]]; then
    echo "[orchestrator] no errors to dispatch"
    return 0
  fi

  local prompt_shared
  prompt_shared="Repository: $ROOT_DIR. Work only on files in your batch. Do not edit files outside your batch. Run at most one focused validation command. Stop after proposing or applying the minimal fixes for listed errors."

  local pid_claude=0 pid_gemini=0 pid_copilot=0 pid_vibe=0

  if [[ -s "$CLAUDE_BATCH" ]]; then
    (
      cd "$ROOT_DIR"
      claude -p --model claude-sonnet-4-6 \
        "$prompt_shared Batch file: $CLAUDE_BATCH. Issue IDs: td-f8df03, td-620770. Output: summary, files touched, command run, residual errors."
    ) >"$CLAUDE_LOG" 2>&1 &
    pid_claude=$!
  else
    echo "SKIPPED: empty batch" >"$CLAUDE_LOG"
  fi

  if [[ -s "$GEMINI_BATCH" ]]; then
    (
      cd "$ROOT_DIR"
      gemini -p \
        "$prompt_shared Batch file: $GEMINI_BATCH. Issue IDs: td-596e3f, td-620770. Output: summary, files touched, command run, residual errors." \
        --approval-mode yolo \
        --output-format text
    ) >"$GEMINI_LOG" 2>&1 &
    pid_gemini=$!
  else
    echo "SKIPPED: empty batch" >"$GEMINI_LOG"
  fi

  if [[ -s "$COPILOT_BATCH" ]]; then
    (
      cd "$ROOT_DIR"
      copilot -p \
        "$prompt_shared Batch file: $COPILOT_BATCH. Issue IDs: td-5cecc9, td-620770. Output: summary, files touched, command run, residual errors." \
        --model gpt-5.3-codex \
        --allow-all-tools \
        --allow-all-paths \
        --allow-all-urls \
        --disable-mcp-server Anigma \
        --no-ask-user \
        -s
    ) >"$COPILOT_LOG" 2>&1 &
    pid_copilot=$!
  else
    echo "SKIPPED: empty batch" >"$COPILOT_LOG"
  fi

  if [[ -s "$VIBE_BATCH" ]]; then
    (
      cd "$ROOT_DIR"
      vibe -p \
        "$prompt_shared Batch file: $VIBE_BATCH. Issue IDs: td-761f53, td-620770. Output: summary, files touched, command run, residual errors." \
        --max-turns 10 \
        --output text
    ) >"$VIBE_LOG" 2>&1 &
    pid_vibe=$!
  else
    echo "SKIPPED: empty batch" >"$VIBE_LOG"
  fi

  echo "[orchestrator] dispatched agents"
  echo "  claude : $pid_claude -> $CLAUDE_LOG"
  echo "  gemini : $pid_gemini -> $GEMINI_LOG"
  echo "  copilot: $pid_copilot -> $COPILOT_LOG"
  echo "  vibe   : $pid_vibe -> $VIBE_LOG"

  watch_processes "$pid_claude" "$pid_gemini" "$pid_copilot" "$pid_vibe"

  [[ "$pid_claude" -ne 0 ]] && wait "$pid_claude" 2>/dev/null || true
  [[ "$pid_gemini" -ne 0 ]] && wait "$pid_gemini" 2>/dev/null || true
  [[ "$pid_copilot" -ne 0 ]] && wait "$pid_copilot" 2>/dev/null || true
  [[ "$pid_vibe" -ne 0 ]] && wait "$pid_vibe" 2>/dev/null || true

  echo "[orchestrator] dispatch complete"
}

main() {
  local cmd="${1:-all}"
  case "$cmd" in
    build-errors) build_errors ;;
    split-errors) split_errors ;;
    dispatch) dispatch ;;
    all)
      build_errors
      split_errors
      dispatch
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      echo "Unknown subcommand: $cmd" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"
