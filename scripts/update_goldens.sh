#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/run-dart-tests.yml"
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# Workflows that may produce golden-images-* artifacts, in priority order.
GOLDEN_WORKFLOWS=("generate-artifacts.yml" "run-dart-tests.yml")

usage() {
    cat <<EOF
Usage: $(basename "$0") [--trigger] [--branch BRANCH]

Update the golden image reference in run-dart-tests.yml.

Options:
  --trigger        Trigger a new generate-artifacts run and wait for it to finish,
                   then use its artifact as the new golden reference.
  --branch BRANCH  Branch to trigger the run on (default: current branch).
                   Only used with --trigger.

With no flags, finds the latest golden-images-* artifact across known workflows.
EOF
    exit 1
}

TRIGGER=false
BRANCH=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --trigger) TRIGGER=true; shift ;;
        --branch)  BRANCH="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

# Find the golden-images-* artifact in a given run
find_golden_artifact() {
    local run_id="$1"
    gh api "repos/$REPO/actions/runs/$run_id/artifacts" \
        --jq '.artifacts[] | select(.name | startswith("golden-images-")) | .name' 2>/dev/null
}

# Search all known workflows for the latest golden artifact
find_latest_golden() {
    for wf in "${GOLDEN_WORKFLOWS[@]}"; do
        local runs
        runs=$(gh run list \
            --workflow="$wf" \
            --limit=5 \
            --json databaseId,status \
            -q '[.[] | select(.status == "completed")] | .[].databaseId')

        for run_id in $runs; do
            local artifact
            artifact=$(find_golden_artifact "$run_id")
            if [[ -n "$artifact" ]]; then
                echo "$run_id"
                echo "$artifact"
                return 0
            fi
        done
    done
    return 1
}

if $TRIGGER; then
    TRIGGER_WORKFLOW="generate-artifacts.yml"
    BRANCH="${BRANCH:-$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)}"
    echo "Triggering $TRIGGER_WORKFLOW on branch '$BRANCH'..."
    gh workflow run "$TRIGGER_WORKFLOW" --ref "$BRANCH"

    echo "Waiting for run to appear..."
    sleep 10

    RUN_ID=$(gh run list \
        --workflow="$TRIGGER_WORKFLOW" \
        --branch="$BRANCH" \
        --limit=1 \
        --json databaseId,status \
        -q '.[0].databaseId')

    echo "Watching run $RUN_ID (this may take a while)..."
    gh run watch "$RUN_ID" --exit-status || {
        echo "Warning: workflow run $RUN_ID failed, but the artifact may still exist."
        echo "Checking for golden-images artifact anyway..."
    }

    ARTIFACT_NAME=$(find_golden_artifact "$RUN_ID")
    if [[ -z "$ARTIFACT_NAME" ]]; then
        echo "Error: no golden-images-* artifact found in triggered run $RUN_ID."
        exit 1
    fi
else
    echo "Searching for latest golden-images artifact..."
    RESULT=$(find_latest_golden) || true
    if [[ -z "$RESULT" ]]; then
        echo "Error: no golden-images-* artifact found in any recent run."
        echo "Use --trigger to start a new run."
        exit 1
    fi
    RUN_ID=$(echo "$RESULT" | head -1)
    ARTIFACT_NAME=$(echo "$RESULT" | tail -1)
fi

echo "Using run $RUN_ID"
echo "Found artifact: $ARTIFACT_NAME"

# Update the workflow file
sed -i '' "s/gh run download [0-9]*/gh run download $RUN_ID/" "$WORKFLOW_FILE"
sed -i '' "s/--name golden-images-[a-f0-9]*/--name $ARTIFACT_NAME/" "$WORKFLOW_FILE"

echo ""
echo "Updated $WORKFLOW_FILE:"
grep -n 'gh run download\|--name golden-images' "$WORKFLOW_FILE"
echo ""
echo "Done. Review the change with: git diff $WORKFLOW_FILE"
