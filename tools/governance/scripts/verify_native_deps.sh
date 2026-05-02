#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
manifest="${1:-$repo_root/DEPS.toml}"

if [[ ! -f "$manifest" ]]; then
  echo "missing native dependency manifest: $manifest" >&2
  exit 1
fi

current_target=""
current_path=""
current_count=""
current_hash=""
failures=0
checked=0

trim_quotes() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  printf '%s' "$value"
}

verify_current() {
  if [[ -z "$current_target" ]]; then
    return
  fi

  if [[ -z "$current_path" || -z "$current_count" || -z "$current_hash" ]]; then
    echo "DEPS.toml entry for $current_target is incomplete" >&2
    failures=$((failures + 1))
    return
  fi

  local absolute_path="$repo_root/$current_path"
  if [[ ! -d "$absolute_path" ]]; then
    echo "native dependency $current_target path missing: $current_path" >&2
    failures=$((failures + 1))
    return
  fi

  local actual_count
  actual_count="$(find "$absolute_path" -type f | wc -l | tr -d ' ')"
  local actual_hash
  actual_hash="$(
    cd "$repo_root"
    find "$current_path" -type f | LC_ALL=C sort | while IFS= read -r file; do
      shasum -a 256 "$file"
    done | shasum -a 256 | cut -d' ' -f1
  )"

  if [[ "$actual_count" != "$current_count" ]]; then
    echo "native dependency $current_target file_count mismatch: expected $current_count got $actual_count" >&2
    failures=$((failures + 1))
  fi

  if [[ "$actual_hash" != "$current_hash" ]]; then
    echo "native dependency $current_target hash mismatch: expected $current_hash got $actual_hash" >&2
    failures=$((failures + 1))
  fi

  if [[ "$actual_count" == "$current_count" && "$actual_hash" == "$current_hash" ]]; then
    echo "verified $current_target $current_hash"
  fi
  checked=$((checked + 1))
}

while IFS= read -r line; do
  case "$line" in
    "[[native_dependency]]")
      verify_current
      current_target=""
      current_path=""
      current_count=""
      current_hash=""
      ;;
    target\ =\ *)
      current_target="$(trim_quotes "${line#target = }")"
      ;;
    path\ =\ *)
      current_path="$(trim_quotes "${line#path = }")"
      ;;
    file_count\ =\ *)
      current_count="${line#file_count = }"
      ;;
    content_sha256\ =\ *)
      current_hash="$(trim_quotes "${line#content_sha256 = }")"
      ;;
  esac
done < "$manifest"

verify_current

if [[ "$checked" -eq 0 ]]; then
  echo "no native_dependency entries found in $manifest" >&2
  exit 1
fi

if [[ "$failures" -ne 0 ]]; then
  echo "native dependency verification failed: $failures issue(s)" >&2
  exit 1
fi

echo "native dependency verification passed: $checked target(s)"
