#!/usr/bin/env bash
set -euo pipefail

MODE="audit"
WITH_GH_COPILOT_EXT=0

usage() {
  cat <<'EOF'
Usage:
  scripts/agentic_tools_audit_install.sh [--install] [--with-gh-copilot-ext]

Options:
  --install               Install missing tools via Homebrew.
  --with-gh-copilot-ext   Also install gh extension github/gh-copilot.
  -h, --help              Show this help.

Default mode is audit-only (no installs).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      MODE="install"
      shift
      ;;
    --with-gh-copilot-ext)
      WITH_GH_COPILOT_EXT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required but not found on PATH." >&2
  exit 1
fi

# command_name:brew_formula
declare -A BREW_TOOLS=(
  [task]="go-task/tap/go-task"
  [shfmt]="shfmt"
  [mise]="mise"
)

# High-value tools to report, even when we don't install them here.
REPORT_ONLY_TOOLS=(
  jq yq rg fd fzf bat eza delta lazygit just direnv tmux entr hyperfine shellcheck
  gh copilot claude vibe gemini openai td sidecar bun pnpm uv node python3
)

print_status() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "FOUND\t%s\t%s\n" "$cmd" "$(command -v "$cmd")"
  else
    printf "MISS\t%s\n" "$cmd"
  fi
}

echo "== Agentic CLI Audit =="
for cmd in "${REPORT_ONLY_TOOLS[@]}"; do
  print_status "$cmd"
done
for cmd in "${!BREW_TOOLS[@]}"; do
  print_status "$cmd"
done | sort

if [[ "$MODE" != "install" ]]; then
  echo
  echo "Audit only. Re-run with --install to install missing managed tools."
  exit 0
fi

echo
echo "== Installing Missing Tools =="
for cmd in "${!BREW_TOOLS[@]}"; do
  formula="${BREW_TOOLS[$cmd]}"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "Skip $cmd (already installed)"
    continue
  fi
  echo "Install $cmd via brew formula $formula"
  brew install "$formula"
done

if [[ "$WITH_GH_COPILOT_EXT" -eq 1 ]]; then
  echo
  echo "== gh-copilot Extension =="
  if ! command -v gh >/dev/null 2>&1; then
    echo "Skip gh-copilot extension (gh not found)"
  elif gh extension list 2>/dev/null | awk '{print $1}' | grep -qx "github/gh-copilot"; then
    echo "Skip github/gh-copilot (already installed)"
  else
    echo "Install github/gh-copilot extension"
    gh extension install github/gh-copilot
  fi
fi

echo
echo "== Final Check =="
for cmd in "${REPORT_ONLY_TOOLS[@]}"; do
  print_status "$cmd"
done
for cmd in "${!BREW_TOOLS[@]}"; do
  print_status "$cmd"
done | sort
