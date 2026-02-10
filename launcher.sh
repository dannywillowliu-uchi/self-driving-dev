#!/usr/bin/env bash
set -euo pipefail

# Self-Driving Dev Session Launcher
# Launches a Claude Code session that follows the session loop in CLAUDE.md
#
# Usage:
#   ./launcher.sh [target] [flags]
#
# Flags:
#   --dry-run      Show what would happen without launching
#   --force        Skip dirty-repo confirmation prompt
#   --background   Run session in background with output logged to file
#   --timeout N    Max runtime in seconds (default: 3600 = 1 hour)
#   --stop         Stop a running background session

DRY_RUN=false
BACKGROUND=false
STOP=false
TIMEOUT=3600
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.session.pid"
LOG_DIR="$SCRIPT_DIR/logs"

# Parse flags
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=true; shift ;;
		--force) FORCE=true; shift ;;
		--background) BACKGROUND=true; shift ;;
		--timeout) TIMEOUT="$2"; shift 2 ;;
		--stop) STOP=true; shift ;;
		*) TARGET="$1"; shift ;;
	esac
done

TARGET="${TARGET:-claude-orchestrator}"
FORCE="${FORCE:-false}"
TARGET_FILE="$SCRIPT_DIR/targets/$TARGET.md"

# Handle --stop: kill background session
if $STOP; then
	if [[ -f "$PID_FILE" ]]; then
		PID=$(cat "$PID_FILE")
		if kill -0 "$PID" 2>/dev/null; then
			echo "Stopping background session (PID $PID)..."
			kill "$PID"
			rm -f "$PID_FILE"
			echo "Session stopped."
		else
			echo "Process $PID not running. Cleaning up PID file."
			rm -f "$PID_FILE"
		fi
	else
		echo "No background session running (no PID file found)."
	fi
	exit 0
fi

# Check for existing background session
if [[ -f "$PID_FILE" ]]; then
	EXISTING_PID=$(cat "$PID_FILE")
	if kill -0 "$EXISTING_PID" 2>/dev/null; then
		echo "Error: Background session already running (PID $EXISTING_PID)."
		echo "Use --stop to terminate it first."
		exit 1
	else
		# Stale PID file
		rm -f "$PID_FILE"
	fi
fi

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
LAST_SESSION=$(ls "$LOG_DIR/" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 || true)
SESSION_NUM=$(printf "%03d" $(( ${LAST_SESSION:-0} + 1 )))

SESSION_LOG="$LOG_DIR/session-${SESSION_NUM}.log"

echo "=== Self-Driving Dev Session $SESSION_NUM ==="
echo "Target: $TARGET ($TARGET_PATH)"
echo "Backlog: $SCRIPT_DIR/BACKLOG.md"
echo "Progress: $SCRIPT_DIR/progress.md"
if $BACKGROUND; then
	echo "Mode: background (timeout: ${TIMEOUT}s)"
	echo "Log: $SESSION_LOG"
fi
echo ""

if $DRY_RUN; then
	echo "[dry run] Would launch: claude --project-dir $SCRIPT_DIR"
	echo "[dry run] Prompt: Read progress.md and BACKLOG.md, then targets/$TARGET.md. Follow session loop."
	if $BACKGROUND; then
		echo "[dry run] Background mode: output -> $SESSION_LOG"
		echo "[dry run] Timeout: ${TIMEOUT}s"
		echo "[dry run] PID file: $PID_FILE"
	fi
	echo ""
	echo "--- progress.md ---"
	head -10 "$SCRIPT_DIR/progress.md"
	echo ""
	echo "--- Next backlog phase ---"
	grep -A1 "^## Phase" "$SCRIPT_DIR/BACKLOG.md" | head -6
	exit 0
fi

PROMPT="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. Continue from where the last session left off. Follow the session loop defined in CLAUDE.md."

if $BACKGROUND; then
	# Background mode: run with nohup, log output, enforce timeout
	mkdir -p "$LOG_DIR"

	(
		# Run claude with timeout
		timeout "${TIMEOUT}s" claude --project-dir "$SCRIPT_DIR" "$PROMPT" \
			> "$SESSION_LOG" 2>&1
		EXIT_CODE=$?

		# Clean up PID file
		rm -f "$PID_FILE"

		if [[ $EXIT_CODE -eq 124 ]]; then
			echo "[$(date)] Session timed out after ${TIMEOUT}s" >> "$SESSION_LOG"
		elif [[ $EXIT_CODE -eq 0 ]]; then
			echo "[$(date)] Session completed successfully" >> "$SESSION_LOG"
		else
			echo "[$(date)] Session exited with code $EXIT_CODE" >> "$SESSION_LOG"
		fi
	) &

	BG_PID=$!
	echo "$BG_PID" > "$PID_FILE"
	echo "Background session started (PID $BG_PID)"
	echo "Monitor: tail -f $SESSION_LOG"
	echo "Stop: ./launcher.sh --stop"
else
	# Foreground mode
	claude --project-dir "$SCRIPT_DIR" "$PROMPT"
fi
