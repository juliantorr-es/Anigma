#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  Scripts/td_stale_tasks.sh [--stale-minutes N] [--long-minutes N] [--json]

Lists in-progress TD tasks and classifies them by last TD update time.

Defaults:
  --stale-minutes 45   Tasks at or above this age need recovery review.
  --long-minutes 90    Tasks at or above this age are stale unless proven active.

Agents should run this before claiming ongoing work. A TD update means any
status change, td log, td comment, or td handoff that refreshes updated_at.
EOF
}

stale_minutes=45
long_minutes=90
json_output=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --stale-minutes)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "td_stale_tasks: --stale-minutes requires an integer" >&2
        exit 2
      fi
      stale_minutes="$2"
      shift 2
      ;;
    --long-minutes)
      if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "td_stale_tasks: --long-minutes requires an integer" >&2
        exit 2
      fi
      long_minutes="$2"
      shift 2
      ;;
    --json)
      json_output=1
      shift
      ;;
    *)
      echo "td_stale_tasks: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if ! command -v td >/dev/null 2>&1; then
  echo "td_stale_tasks: td command not found" >&2
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "td_stale_tasks: jq command not found" >&2
  exit 127
fi

to_epoch() {
  local raw="$1"
  local normalized

  if [[ -z "$raw" ]]; then
    return 1
  fi

  normalized="$(printf '%s' "$raw" | sed -E 's/\.[0-9]+//; s/([+-][0-9]{2}):([0-9]{2})$/\1\2/')"

  if date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s' >/dev/null 2>&1; then
    date -j -f '%Y-%m-%dT%H:%M:%S%z' "$normalized" '+%s'
  elif date -d "$raw" '+%s' >/dev/null 2>&1; then
    date -d "$raw" '+%s'
  else
    return 1
  fi
}

age_label() {
  local minutes="$1"

  if [[ "$minutes" == "null" ]]; then
    printf 'unknown'
  elif (( minutes >= 1440 )); then
    printf '%dd' "$(( minutes / 1440 ))"
  elif (( minutes >= 60 )); then
    printf '%dh%02dm' "$(( minutes / 60 ))" "$(( minutes % 60 ))"
  else
    printf '%dm' "$minutes"
  fi
}

decode_issue() {
  if base64 --decode >/dev/null 2>&1 <<<"$1"; then
    base64 --decode <<<"$1"
  else
    base64 -D <<<"$1"
  fi
}

tmp_rows="$(mktemp)"
tmp_json="$(mktemp)"
trap 'rm -f "$tmp_rows" "$tmp_json"' EXIT

now_epoch="$(date '+%s')"

td list --status in_progress --json |
  jq -r '.[] | @base64' |
  while IFS= read -r encoded_issue; do
    issue_json="$(decode_issue "$encoded_issue")"
    issue_id="$(jq -r '.id // ""' <<<"$issue_json")"
    priority="$(jq -r '.priority // ""' <<<"$issue_json")"
    issue_type="$(jq -r '.type // ""' <<<"$issue_json")"
    session="$(jq -r '.implementer_session // ""' <<<"$issue_json")"
    updated_at="$(jq -r '.updated_at // ""' <<<"$issue_json")"
    title="$(jq -r '(.title // "") | gsub("[\n\r\t]"; " ")' <<<"$issue_json")"

    age_minutes="null"
    classification="UNKNOWN"
    rank=1

    if updated_epoch="$(to_epoch "$updated_at")"; then
      age_minutes="$(( (now_epoch - updated_epoch) / 60 ))"
      if (( age_minutes < 0 )); then
        age_minutes=0
      fi

      if (( age_minutes >= long_minutes )); then
        classification="STALE"
        rank=0
      elif (( age_minutes >= stale_minutes )); then
        classification="REVIEW"
        rank=2
      else
        classification="ACTIVE"
        rank=3
      fi
    fi

    sort_age=0
    if [[ "$age_minutes" != "null" ]]; then
      sort_age=$(( -age_minutes ))
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$rank" "$sort_age" "$classification" "$age_minutes" "$issue_id" \
      "$priority" "$issue_type" "$session" "$updated_at" "$title" >>"$tmp_rows"

    jq -n \
      --arg classification "$classification" \
      --arg id "$issue_id" \
      --arg priority "$priority" \
      --arg type "$issue_type" \
      --arg implementer_session "$session" \
      --arg updated_at "$updated_at" \
      --arg title "$title" \
      --argjson age_minutes "$age_minutes" \
      '{
        classification: $classification,
        id: $id,
        priority: $priority,
        type: $type,
        implementer_session: $implementer_session,
        updated_at: $updated_at,
        age_minutes: $age_minutes,
        title: $title
      }' >>"$tmp_json"
  done

if [[ "$json_output" -eq 1 ]]; then
  if [[ -s "$tmp_json" ]]; then
    jq -s 'sort_by(
      if .classification == "STALE" then 0
      elif .classification == "UNKNOWN" then 1
      elif .classification == "REVIEW" then 2
      else 3 end,
      -(.age_minutes // 0),
      .priority,
      .id
    )' "$tmp_json"
  else
    printf '[]\n'
  fi
  exit 0
fi

echo "TD in-progress task freshness (review >= ${stale_minutes}m, stale >= ${long_minutes}m)"
echo "CLASS    AGE      ID         PRI TYPE     SESSION      TITLE"
echo "-----    ---      --         --- ----     -------      -----"

if [[ ! -s "$tmp_rows" ]]; then
  echo "No in-progress tasks found."
  exit 0
fi

sort -t $'\t' -k1,1n -k2,2n -k6,6 -k5,5 "$tmp_rows" |
  while IFS=$'\t' read -r _rank _sort_age classification age_minutes issue_id priority issue_type session _updated_at title; do
    if [[ -z "$session" ]]; then
      session="-"
    fi

    printf '%-8s %-8s %-10s %-3s %-8s %-12s %s\n' \
      "$classification" "$(age_label "$age_minutes")" "$issue_id" "$priority" \
      "$issue_type" "$session" "$title"
  done

echo
echo "Use RECOVERY logs before taking over STALE or UNKNOWN work:"
echo '  td log <issue-id> "RECOVERY: task appears stale; resuming from TD handoff and current worktree."'
