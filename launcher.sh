#!/usr/bin/env bash
set -euo pipefail

# Self-Driving Dev Session Launcher
# Launches a Claude Code session that follows the session loop in CLAUDE.md

DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse flags
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=true; shift ;;
		--force) FORCE=true; shift ;;
		*) TARGET="$1"; shift ;;
	esac
done

TARGET="${TARGET:-claude-orchestrator}"
FORCE="${FORCE:-false}"
TARGET_FILE="$SCRIPT_DIR/targets/$TARGET.md"

# Validate target exists
if [[ ! -f "$TARGET_FILE" ]]; then
	echo "Error: Target file not found: $TARGET_FILE"
	echo "Available targets:"
	ls "$SCRIPT_DIR/targets/"
	exit 1
fi

# Extract target repo path from target file
TARGET_PATH=$(grep -A1 "^- Path:" "$TARGET_FILE" | head -1 | sed 's/.*`\(.*\)`.*/\1/')
TARGET_PATH="${TARGET_PATH/#\~/$HOME}"

# Validate target repo exists and is clean
if [[ ! -d "$TARGET_PATH" ]]; then
	echo "Error: Target repo not found: $TARGET_PATH"
	exit 1
fi

if [[ -n "$(git -C "$TARGET_PATH" status --porcelain)" ]]; then
	echo "Warning: Target repo has uncommitted changes."
	if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
		echo "Proceed anyway? (y/N) (use --force to skip this prompt)"
		read -r response
		if [[ "$response" != "y" && "$response" != "Y" ]]; then
			echo "Aborted."
			exit 1
		fi
	else
		echo "(continuing -- $(if $DRY_RUN; then echo "dry run"; else echo "--force"; fi))"
	fi
fi

# Determine session number
LAST_SESSION=$(ls "$SCRIPT_DIR/logs/" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 || true)
SESSION_NUM=$(printf "%03d" $(( ${LAST_SESSION:-0} + 1 )))

echo "=== Self-Driving Dev Session $SESSION_NUM ==="
echo "Target: $TARGET ($TARGET_PATH)"
echo "Backlog: $SCRIPT_DIR/BACKLOG.md"
echo "Progress: $SCRIPT_DIR/progress.md"
echo ""

if $DRY_RUN; then
	echo "[dry run] Would launch: claude --project-dir $SCRIPT_DIR"
	echo "[dry run] Prompt: Read progress.md and BACKLOG.md, then targets/$TARGET.md. Follow session loop."
	echo ""
	echo "--- progress.md ---"
	head -10 "$SCRIPT_DIR/progress.md"
	echo ""
	echo "--- Next backlog phase ---"
	grep -A1 "^## Phase" "$SCRIPT_DIR/BACKLOG.md" | head -6
	exit 0
fi

# Launch Claude Code with initial prompt
claude --project-dir "$SCRIPT_DIR" \
	"Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. Continue from where the last session left off. Follow the session loop defined in CLAUDE.md."
