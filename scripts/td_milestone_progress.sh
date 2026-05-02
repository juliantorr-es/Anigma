#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  Scripts/td_milestone_progress.sh <issue-id>
  Scripts/td_milestone_progress.sh --milestone <epic-id>

Reports completion percentage for the milestone associated with an issue.

Rules:
  - If <issue-id> has a parent_id, the parent is treated as the milestone.
  - If <issue-id> is an epic, that epic is treated as the milestone.
  - Progress is weighted by story points when child points are nonzero.
  - Otherwise progress falls back to direct-child task count.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 2
fi

mode="issue"
target=""

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --milestone)
    if [[ $# -ne 2 ]]; then
      usage >&2
      exit 2
    fi
    mode="milestone"
    target="$2"
    ;;
  *)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 2
    fi
    target="$1"
    ;;
esac

if ! command -v td >/dev/null 2>&1; then
  echo "td_milestone_progress: td command not found" >&2
  exit 127
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "td_milestone_progress: jq command not found" >&2
  exit 127
fi

td_json="$(td export --format json --all)"

jq_program='
  def issue_by_id($id): map(.issue) | map(select(.id == $id)) | first;
  def children_of($id): map(.issue) | map(select(.parent_id == $id));
  def priority_rank:
    if .priority == "P0" then 0
    elif .priority == "P1" then 1
    elif .priority == "P2" then 2
    elif .priority == "P3" then 3
    elif .priority == "P4" then 4
    else 9 end;
  def openish: select(.status != "closed" and .status != "deleted");

  . as $rows
  | ($rows | issue_by_id($target)) as $target_issue
  | if $target_issue == null then
      error("Issue not found: " + $target)
    else
      (if $mode == "milestone" then
        $target_issue
      elif ($target_issue.parent_id // "") != "" then
        ($rows | issue_by_id($target_issue.parent_id))
      elif $target_issue.type == "epic" then
        $target_issue
      else
        null
      end) as $milestone
      | if $milestone == null then
          {
            kind: "no_milestone",
            issue_id: $target_issue.id,
            issue_title: $target_issue.title,
            message: ("No parent epic/milestone found for " + $target_issue.id)
          }
        else
          ($rows | children_of($milestone.id)) as $children
          | ($children | length) as $total_count
          | ($children | map(select(.status == "closed")) | length) as $closed_count
          | ($children | map(select(.status == "in_review")) | length) as $review_count
          | ($children | map(.points // 0) | add // 0) as $total_points
          | ($children | map(select(.status == "closed") | (.points // 0)) | add // 0) as $closed_points
          | (if $total_points > 0 then (($closed_points / $total_points) * 100) else (if $total_count > 0 then (($closed_count / $total_count) * 100) else 0 end) end) as $percent
          | ($children | map(openish) | sort_by(priority_rank, .created_at) | first) as $next_child
          | {
              kind: "milestone_progress",
              completed_issue_id: $target_issue.id,
              completed_issue_title: $target_issue.title,
              milestone_id: $milestone.id,
              milestone_title: $milestone.title,
              metric: (if $total_points > 0 then "points" else "tasks" end),
              percent: $percent,
              closed_count: $closed_count,
              total_count: $total_count,
              in_review_count: $review_count,
              closed_points: $closed_points,
              total_points: $total_points,
              next_issue_id: ($next_child.id // null),
              next_issue_title: ($next_child.title // null),
              next_issue_status: ($next_child.status // null),
              next_issue_priority: ($next_child.priority // null)
            }
        end
    end
'

progress_json="$(jq --arg mode "$mode" --arg target "$target" "$jq_program" <<<"$td_json")"

kind="$(jq -r '.kind' <<<"$progress_json")"

if [[ "$kind" == "no_milestone" ]]; then
  jq -r '.message' <<<"$progress_json"
  exit 0
fi

metric="$(jq -r '.metric' <<<"$progress_json")"
milestone_id="$(jq -r '.milestone_id' <<<"$progress_json")"
milestone_title="$(jq -r '.milestone_title' <<<"$progress_json")"
percent="$(jq -r '.percent | floor' <<<"$progress_json")"
closed_count="$(jq -r '.closed_count' <<<"$progress_json")"
total_count="$(jq -r '.total_count' <<<"$progress_json")"
review_count="$(jq -r '.in_review_count' <<<"$progress_json")"
closed_points="$(jq -r '.closed_points' <<<"$progress_json")"
total_points="$(jq -r '.total_points' <<<"$progress_json")"
next_issue_id="$(jq -r '.next_issue_id // empty' <<<"$progress_json")"
next_issue_title="$(jq -r '.next_issue_title // empty' <<<"$progress_json")"
next_issue_status="$(jq -r '.next_issue_status // empty' <<<"$progress_json")"
next_issue_priority="$(jq -r '.next_issue_priority // empty' <<<"$progress_json")"

echo "Milestone progress: ${milestone_id} \"${milestone_title}\" is ${percent}% complete."

if [[ "$metric" == "points" ]]; then
  echo "Completed: ${closed_points}/${total_points} points across ${closed_count}/${total_count} child tasks (${review_count} in review)."
else
  echo "Completed: ${closed_count}/${total_count} child tasks (${review_count} in review)."
fi

if [[ -n "$next_issue_id" ]]; then
  echo "Next remaining child: ${next_issue_id} [${next_issue_priority}, ${next_issue_status}] ${next_issue_title}"
else
  echo "Next remaining child: none. Milestone child task set is complete."
fi
