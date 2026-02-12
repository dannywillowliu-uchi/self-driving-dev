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
#   --discover     Run discovery loop only (no execution)
#   --loop         Continuous mode: re-launch sessions until timeout or --stop

DRY_RUN=false
BACKGROUND=false
DISCOVER=false
STOP=false
LOOP=false
TIMEOUT=3600
MAX_PARALLEL="${MAX_PARALLEL:-3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/.session.pid"
LOG_DIR="$SCRIPT_DIR/logs"

# Parse flags
while [[ $# -gt 0 ]]; do
	case "$1" in
		--dry-run) DRY_RUN=true; shift ;;
		--force) FORCE=true; shift ;;
		--background) BACKGROUND=true; shift ;;
		--discover) DISCOVER=true; shift ;;
		--timeout) TIMEOUT="$2"; shift 2 ;;
		--stop) STOP=true; shift ;;
		--loop) LOOP=true; shift ;;
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

# Unset invalid API key so claude uses OAuth auth
unset ANTHROPIC_API_KEY

# macOS-compatible timeout function (GNU timeout not available)
run_with_timeout() {
	local secs="$1"
	shift
	"$@" &
	local cmd_pid=$!
	(
		sleep "$secs"
		kill "$cmd_pid" 2>/dev/null
	) &
	local watcher_pid=$!
	wait "$cmd_pid" 2>/dev/null
	local exit_code=$?
	kill "$watcher_pid" 2>/dev/null
	wait "$watcher_pid" 2>/dev/null
	return $exit_code
}

# Function to get the next session number
get_session_num() {
	local last
	last=$(ls "$LOG_DIR/" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 || true)
	# Use 10# to force base-10 interpretation (avoid octal with leading zeros)
	printf "%03d" $(( 10#${last:-0} + 1 ))
}

# Function to check if there's remaining work in backlog
# Checks progress.md (the execution record) not BACKLOG.md (the immutable spec)
has_remaining_work() {
	if grep -qi "all.*phases complete\|ready for.*discovery" "$SCRIPT_DIR/progress.md" 2>/dev/null; then
		return 1  # Execution done -> no remaining work -> trigger discovery
	fi
	return 0  # Work remains -> continue execution
}

# --- Dependency graph (bash 3.2 compatible, no associative arrays) ---
# Uses parallel arrays: PHASE_NUMBERS[i] and PHASE_DEPS_LIST[i]

# Parse dependency graph from BACKLOG.md
# Populates: PHASE_NUMBERS=() and PHASE_DEPS_LIST=() (parallel arrays)
parse_dependencies() {
	PHASE_NUMBERS=()
	PHASE_DEPS_LIST=()

	local backlog="$SCRIPT_DIR/BACKLOG.md"
	local current_phase=""
	local current_idx=-1
	while IFS= read -r line; do
		if [[ "$line" =~ ^##\ Phase\ ([0-9]+): ]]; then
			current_phase="${BASH_REMATCH[1]}"
			PHASE_NUMBERS+=("$current_phase")
			PHASE_DEPS_LIST+=("")  # default: no deps
			current_idx=$(( ${#PHASE_NUMBERS[@]} - 1 ))
		fi
		if [[ $current_idx -ge 0 && "$line" =~ ^\*\*Dependencies:\*\*\ *(.*) ]]; then
			local dep_text="${BASH_REMATCH[1]}"
			if [[ "$dep_text" != "None" && -n "$dep_text" ]]; then
				local deps=""
				while [[ "$dep_text" =~ Phase\ ([0-9]+) ]]; do
					deps+="${BASH_REMATCH[1]} "
					dep_text="${dep_text#*Phase ${BASH_REMATCH[1]}}"
				done
				PHASE_DEPS_LIST[$current_idx]="${deps% }"
			fi
			current_idx=-1  # Done with this phase's deps
		fi
	done < "$backlog"
}

# Look up deps for a phase number (returns via LOOKUP_RESULT)
get_phase_deps() {
	local target="$1"
	LOOKUP_RESULT=""
	local i
	for (( i=0; i<${#PHASE_NUMBERS[@]}; i++ )); do
		if [[ "${PHASE_NUMBERS[$i]}" == "$target" ]]; then
			LOOKUP_RESULT="${PHASE_DEPS_LIST[$i]}"
			return 0
		fi
	done
	return 1
}

# Extract completed phase numbers from progress.md session history
# Only parses lines AFTER "## Session History" to avoid false matches
# from the Current State section (e.g., "phases 51-53" in status text)
get_completed_phases() {
	COMPLETED_PHASES=()
	local progress="$SCRIPT_DIR/progress.md"
	local in_history=false

	while IFS= read -r line; do
		# Only start parsing after Session History header
		if [[ "$line" =~ ^##\ Session\ History ]]; then
			in_history=true
			continue
		fi
		if ! $in_history; then continue; fi

		# Only parse two kinds of lines:
		# 1) <summary> lines (but skip Discovery sessions)
		# 2) **Phase N Commit:** or **Phase N:** lines (commit references in body)

		if [[ "$line" =~ \<summary\> ]]; then
			# Skip discovery sessions -- they mention NEW phases, not completed ones
			if [[ "$line" =~ Discovery ]]; then continue; fi

			# Match range like "Phases 8-12" or "Phases 54-56"
			if [[ "$line" =~ Phases\ ([0-9]+)-([0-9]+) ]]; then
				local start="${BASH_REMATCH[1]}"
				local end="${BASH_REMATCH[2]}"
				local i
				for (( i=start; i<=end; i++ )); do
					COMPLETED_PHASES+=("$i")
				done
			# Match space-separated like "Phases 21 22 23:" (parallel merges)
			elif [[ "$line" =~ Phases\ ([0-9]+([\ ][0-9]+)+): ]]; then
				local nums="${BASH_REMATCH[1]}"
				local n
				for n in $nums; do
					COMPLETED_PHASES+=("$n")
				done
			# Match combined like "Phase 4+5" or "Phase 6+7"
			elif [[ "$line" =~ Phase\ ([0-9]+)\+([0-9]+) ]]; then
				COMPLETED_PHASES+=("${BASH_REMATCH[1]}")
				COMPLETED_PHASES+=("${BASH_REMATCH[2]}")
			fi
			# Extract single "Phase N:" from summary title
			local tmp="$line"
			while [[ "$tmp" =~ Phase\ ([0-9]+): ]]; do
				local found="${BASH_REMATCH[1]}"
				COMPLETED_PHASES+=("$found")
				tmp="${tmp#*Phase ${found}:}"
			done
		elif [[ "$line" =~ \*\*Phase\ ([0-9]+)( Commit)?\:\*\* ]]; then
			# Body lines like "- **Phase 26:** 3c7f3a1" or "- **Phase 4 Commit:** 4b1f9bf"
			COMPLETED_PHASES+=("${BASH_REMATCH[1]}")
		fi
	done < "$progress"

	# Deduplicate
	if [[ ${#COMPLETED_PHASES[@]} -gt 0 ]]; then
		local unique=()
		local p already
		for p in "${COMPLETED_PHASES[@]}"; do
			already=false
			for u in "${unique[@]+"${unique[@]}"}"; do
				if [[ "$u" == "$p" ]]; then
					already=true
					break
				fi
			done
			if ! $already; then
				unique+=("$p")
			fi
		done
		COMPLETED_PHASES=("${unique[@]}")
	fi
}

# Check if a phase number is in COMPLETED_PHASES
is_phase_completed() {
	local target="$1"
	local c
	for c in "${COMPLETED_PHASES[@]+"${COMPLETED_PHASES[@]}"}"; do
		if [[ "$c" == "$target" ]]; then
			return 0
		fi
	done
	return 1
}

# Determine which phases can execute now (not completed, all deps met)
# Returns results in RUNNABLE_PHASES array, capped at MAX_PARALLEL
get_runnable_phases() {
	parse_dependencies
	get_completed_phases
	RUNNABLE_PHASES=()

	local phase
	for phase in "${PHASE_NUMBERS[@]}"; do
		# Skip completed phases
		if is_phase_completed "$phase"; then continue; fi

		# Check all dependencies are completed
		get_phase_deps "$phase" || true
		local deps="$LOOKUP_RESULT"
		local all_deps_met=true
		if [[ -n "$deps" ]]; then
			local dep
			for dep in $deps; do
				if ! is_phase_completed "$dep"; then
					all_deps_met=false
					break
				fi
			done
		fi

		if $all_deps_met; then
			RUNNABLE_PHASES+=("$phase")
		fi

		# Cap at MAX_PARALLEL
		if [[ ${#RUNNABLE_PHASES[@]} -ge $MAX_PARALLEL ]]; then
			break
		fi
	done
}

# Create a git worktree for isolated phase execution
create_worktree() {
	local phase_num="$1"
	local worktree_dir="$TARGET_PATH/.worktrees/phase-$phase_num"

	mkdir -p "$TARGET_PATH/.worktrees"

	# Remove stale worktree if it exists
	if [[ -d "$worktree_dir" ]]; then
		git -C "$TARGET_PATH" worktree remove "$worktree_dir" --force 2>/dev/null || true
		git -C "$TARGET_PATH" branch -D "phase-$phase_num" 2>/dev/null || true
	fi

	# Create worktree with a new branch from current HEAD
	if ! git -C "$TARGET_PATH" worktree add "$worktree_dir" -b "phase-$phase_num" HEAD > /dev/null 2>&1; then
		echo "Error: Failed to create worktree for phase $phase_num"
		return 1
	fi

	# Symlink .venv if it exists (phases don't install new deps)
	if [[ -d "$TARGET_PATH/.venv" ]]; then
		ln -sf "$TARGET_PATH/.venv" "$worktree_dir/.venv"
	fi

	echo "$worktree_dir"
}

# Clean up a worktree after merge
cleanup_worktree() {
	local phase_num="$1"
	local worktree_dir="$TARGET_PATH/.worktrees/phase-$phase_num"

	if [[ -d "$worktree_dir" ]]; then
		# Remove symlinked .venv first to avoid deleting real venv
		rm -f "$worktree_dir/.venv"
		git -C "$TARGET_PATH" worktree remove "$worktree_dir" --force 2>/dev/null || true
	fi
	git -C "$TARGET_PATH" branch -D "phase-$phase_num" 2>/dev/null || true
}

# Extract verification command from target file
get_verification_command() {
	local target_file="$1"
	sed -n '/^## Verification Command/,/^```$/p' "$target_file" | sed -n '/^```bash/,/^```$/p' | grep -v '^```'
}

# Run multiple phases in parallel using git worktrees
run_parallel_phases() {
	local input_phases=("$@")
	# Arrays that stay aligned: only phases with successful worktrees
	PARALLEL_PHASES=()
	PARALLEL_WORKTREES=()
	PARALLEL_PIDS=()
	local session_nums=()

	local verification_cmd
	verification_cmd=$(get_verification_command "$TARGET_FILE")

	echo "[$(date)] Launching up to ${#input_phases[@]} parallel agents: phases ${input_phases[*]}"

	local phase
	for phase in "${input_phases[@]}"; do
		local worktree_dir
		if ! worktree_dir=$(create_worktree "$phase"); then
			echo "[$(date)] Worktree creation failed for phase $phase, skipping"
			continue
		fi

		# Reserve session number and touch log file to prevent race
		local session_num
		session_num=$(get_session_num)
		local session_log="$LOG_DIR/session-${session_num}.log"
		touch "$session_log"

		# Get phase title from BACKLOG.md
		local phase_title
		phase_title=$(grep "^## Phase $phase:" "$SCRIPT_DIR/BACKLOG.md" | sed "s/^## Phase $phase: //")

		local phase_prompt
		phase_prompt="Read $SCRIPT_DIR/BACKLOG.md and find Phase $phase. Implement ONLY Phase $phase -- do not work on any other phase. The working directory is a git worktree branched from main. Read $SCRIPT_DIR/targets/$TARGET.md for target-specific context. After implementation:
1. Run verification: $verification_cmd
2. If verification passes, commit with message \"Phase $phase: $phase_title\"
3. Write a JSON result file to .phase-result.json in the repo root with: {\"status\":\"success\",\"summary\":\"<brief summary>\"}
If verification fails after 3 attempts, write: {\"status\":\"failed\",\"summary\":\"<what went wrong>\"}
Do NOT modify files outside this working directory. Do NOT work on any phase other than Phase $phase."

		echo "[$(date)] Phase $phase: worktree=$worktree_dir session=$session_num" >> "$session_log"

		# Launch agent in background (skip permissions since -p mode can't prompt)
		(
			cd "$worktree_dir"
			claude \
				--dangerously-skip-permissions \
				-p "$phase_prompt" >> "$session_log" 2>&1
		) &

		# Track in aligned arrays
		PARALLEL_PHASES+=("$phase")
		PARALLEL_WORKTREES+=("$worktree_dir")
		PARALLEL_PIDS+=($!)
		session_nums+=("$session_num")

		echo "  Phase $phase -> PID ${PARALLEL_PIDS[${#PARALLEL_PIDS[@]}-1]} (session $session_num, log: $session_log)"
	done

	if [[ ${#PARALLEL_PIDS[@]} -eq 0 ]]; then
		echo "[$(date)] No agents launched (all worktree creations failed)"
		return 1
	fi

	# Wait for all agents to complete
	echo "[$(date)] Waiting for ${#PARALLEL_PIDS[@]} agents to complete..."
	local failed=0
	local i
	for (( i=0; i<${#PARALLEL_PIDS[@]}; i++ )); do
		wait "${PARALLEL_PIDS[$i]}" 2>/dev/null || true
		local p="${PARALLEL_PHASES[$i]}"
		local wt="${PARALLEL_WORKTREES[$i]}"
		local result_file="$wt/.phase-result.json"

		if [[ -f "$result_file" ]]; then
			local status
			status=$(grep -o '"status":"[^"]*"' "$result_file" | head -1 | cut -d'"' -f4)
			echo "  Phase $p: $status"
		else
			echo "  Phase $p: no result file (agent may have crashed)"
			failed=$((failed + 1))
		fi
	done

	echo "[$(date)] All agents complete. $failed failed."
	return 0
}

# Merge completed phase branches back to main sequentially
merge_phase_results() {
	local phases=("$@")
	local merged=()
	local failed=()

	echo "[$(date)] Merging results for phases: ${phases[*]}"

	local phase
	for phase in "${phases[@]}"; do
		local worktree_dir="$TARGET_PATH/.worktrees/phase-$phase"
		local result_file="$worktree_dir/.phase-result.json"

		# Check if phase succeeded
		if [[ ! -f "$result_file" ]]; then
			echo "  Phase $phase: skipped (no result file)"
			failed+=("$phase")
			cleanup_worktree "$phase"
			continue
		fi

		local status
		status=$(grep -o '"status":"[^"]*"' "$result_file" | head -1 | cut -d'"' -f4)
		if [[ "$status" != "success" ]]; then
			echo "  Phase $phase: skipped (status=$status)"
			failed+=("$phase")
			cleanup_worktree "$phase"
			continue
		fi

		# Check for merge conflicts via trial merge
		if ! git -C "$TARGET_PATH" merge --no-commit --no-ff "phase-$phase" 2>/dev/null; then
			echo "  Phase $phase: CONFLICT detected, aborting merge (will retry next cycle)"
			git -C "$TARGET_PATH" merge --abort 2>/dev/null || true
			failed+=("$phase")
			cleanup_worktree "$phase"
			continue
		fi

		# Commit the merge
		local phase_title
		phase_title=$(grep "^## Phase $phase:" "$SCRIPT_DIR/BACKLOG.md" | sed "s/^## Phase $phase: //")

		git -C "$TARGET_PATH" commit --no-edit -m "Merge phase-$phase: $phase_title" 2>/dev/null

		# Run verification on merged result (5 minute timeout)
		local verification_cmd
		verification_cmd=$(get_verification_command "$TARGET_FILE")
		echo "  Phase $phase: running verification after merge..."

		local verify_ok=false
		(cd "$TARGET_PATH" && eval "$verification_cmd" > /dev/null 2>&1) &
		local verify_pid=$!
		local waited=0
		while kill -0 "$verify_pid" 2>/dev/null; do
			sleep 5
			waited=$((waited + 5))
			if [[ $waited -ge 300 ]]; then
				echo "  Phase $phase: verification TIMED OUT after 300s"
				kill "$verify_pid" 2>/dev/null
				wait "$verify_pid" 2>/dev/null
				break
			fi
		done
		if [[ $waited -lt 300 ]]; then
			if wait "$verify_pid" 2>/dev/null; then
				verify_ok=true
			fi
		fi

		if $verify_ok; then
			echo "  Phase $phase: MERGED successfully"
			merged+=("$phase")
		else
			echo "  Phase $phase: verification FAILED after merge, reverting"
			if ! git -C "$TARGET_PATH" reset --hard HEAD~1; then
				echo "  Phase $phase: WARNING: git reset failed"
			fi
			failed+=("$phase")
		fi

		cleanup_worktree "$phase"
	done

	# Update progress.md with merged phases
	if [[ ${#merged[@]} -gt 0 ]]; then
		local commit_hash
		commit_hash=$(git -C "$TARGET_PATH" rev-parse --short HEAD)
		local merged_list="${merged[*]}"
		echo "[$(date)] Successfully merged phases: $merged_list (commit: $commit_hash)"

		# Update progress.md current state
		local progress="$SCRIPT_DIR/progress.md"
		get_runnable_phases
		local next_phase=""
		if [[ ${#RUNNABLE_PHASES[@]} -gt 0 ]]; then
			next_phase="${RUNNABLE_PHASES[0]}"
		fi

		# Phase display: list individual phases (they may not be contiguous)
		local phase_display
		if [[ ${#merged[@]} -eq 1 ]]; then
			phase_display="Phase ${merged[0]}"
		else
			phase_display="Phases ${merged[*]}"
		fi

		sed -i '' "s/^Phase: .*/Phase: $phase_display complete/" "$progress"
		sed -i '' "s/^Active Task: .*/Active Task: ${next_phase:+Phase $next_phase}/" "$progress"
		sed -i '' "s/^Last Commit: .*/Last Commit: $commit_hash (phases $merged_list)/" "$progress"

		# Append session history entry so get_completed_phases sees these phases
		local session_num
		session_num=$(get_session_num)
		touch "$LOG_DIR/session-${session_num}.log"
		local today
		today=$(date +%Y-%m-%d)

		# Build per-phase summary from result files
		local summaries=""
		local mp
		for mp in "${merged[@]}"; do
			local mp_title
			mp_title=$(grep "^## Phase $mp:" "$SCRIPT_DIR/BACKLOG.md" | sed "s/^## Phase $mp: //")
			summaries="$summaries Phase $mp: $mp_title."
		done

		# Insert session entry after "## Session History" line
		sed -i '' "/^## Session History$/a\\
\\
<details>\\
<summary>Session $session_num - $phase_display: Parallel merge</summary>\\
\\
- **Date:** $today\\
- **Target:** $TARGET\\
- **Commit:** $commit_hash\\
- **Summary:**$summaries\\
</details>" "$progress"
	fi

	if [[ ${#failed[@]} -gt 0 ]]; then
		echo "[$(date)] Failed/skipped phases: ${failed[*]} (will retry next cycle)"
	fi

	# Clean up .worktrees dir if empty
	rmdir "$TARGET_PATH/.worktrees" 2>/dev/null || true
}

# Function to run a single session
run_single_session() {
	local session_num="$1"
	local session_log="$LOG_DIR/session-${session_num}.log"
	local is_discovery="$2"

	local prompt
	if [[ "$is_discovery" == "true" ]]; then
		prompt="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. All backlog phases should be complete. Run the Continuous Discovery loop from CLAUDE.md: audit the target repo, rank opportunities, and write 1-3 new phases to BACKLOG.md. Do NOT execute any implementation -- discovery only."
	else
		prompt="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. Continue from where the last session left off. Follow the session loop defined in CLAUDE.md. Do NOT pause at checkpoints -- execute all phases continuously until the backlog is complete or you encounter a blocking error."
	fi

	echo "[$(date)] Starting session $session_num ($(if [[ "$is_discovery" == "true" ]]; then echo "discovery"; else echo "execution"; fi))" >> "$session_log"

	claude --allowedTools "Bash(description:*),Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,mcp__claude-orchestrator__*,mcp__obsidian__*" "$prompt" \
		>> "$session_log" 2>&1
	return $?
}

SESSION_NUM=$(get_session_num)
SESSION_LOG="$LOG_DIR/session-${SESSION_NUM}.log"

echo "=== Self-Driving Dev Session $SESSION_NUM ==="
echo "Target: $TARGET ($TARGET_PATH)"
echo "Backlog: $SCRIPT_DIR/BACKLOG.md"
echo "Progress: $SCRIPT_DIR/progress.md"
if $LOOP; then
	echo "Mode: continuous loop (timeout: ${TIMEOUT}s, max parallel: $MAX_PARALLEL)"
fi
if $BACKGROUND; then
	echo "Mode: background (timeout: ${TIMEOUT}s)"
	echo "Log: $SESSION_LOG"
fi
echo ""

if $DRY_RUN; then
	echo "[dry run] Would launch: claude --project-dir $SCRIPT_DIR"
	if $DISCOVER; then
		echo "[dry run] Mode: discovery only"
		echo "[dry run] Prompt: Run discovery loop from CLAUDE.md. Audit target, find opportunities, write new backlog phases."
	elif $LOOP; then
		echo "[dry run] Mode: continuous loop"
		echo "[dry run] Cycle: execute phases -> discovery -> execute discovered phases -> discovery -> ..."
		echo "[dry run] Timeout: ${TIMEOUT}s total"
		echo "[dry run] Max parallel agents: $MAX_PARALLEL"
	else
		echo "[dry run] Prompt: Read progress.md and BACKLOG.md, then targets/$TARGET.md. Follow session loop."
	fi
	if $BACKGROUND; then
		echo "[dry run] Background mode: output -> $SESSION_LOG"
		echo "[dry run] PID file: $PID_FILE"
	fi
	echo ""
	echo "--- progress.md ---"
	head -10 "$SCRIPT_DIR/progress.md"
	echo ""

	# Show dependency analysis and runnable phases
	get_runnable_phases
	echo "--- Completed phases ---"
	if [[ ${#COMPLETED_PHASES[@]} -gt 0 ]]; then
		echo "${COMPLETED_PHASES[*]}"
	else
		echo "(none)"
	fi
	echo ""
	echo "--- Runnable phases (max $MAX_PARALLEL) ---"
	if [[ ${#RUNNABLE_PHASES[@]} -eq 0 ]]; then
		echo "(none -- all complete or blocked, would trigger discovery)"
	elif [[ ${#RUNNABLE_PHASES[@]} -eq 1 ]]; then
		p="${RUNNABLE_PHASES[0]}"
		title=$(grep "^## Phase $p:" "$SCRIPT_DIR/BACKLOG.md" | sed "s/^## Phase $p: //")
		echo "Phase $p: $title (sequential -- single phase)"
	else
		echo "PARALLEL execution plan:"
		for p in "${RUNNABLE_PHASES[@]}"; do
			title=$(grep "^## Phase $p:" "$SCRIPT_DIR/BACKLOG.md" | sed "s/^## Phase $p: //")
			get_phase_deps "$p" || true
			echo "  Phase $p: $title (deps: ${LOOKUP_RESULT:-none})"
		done
	fi
	exit 0
fi

if $DISCOVER; then
	PROMPT="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. All backlog phases should be complete. Run the Continuous Discovery loop from CLAUDE.md: audit the target repo, rank opportunities, and write 1-3 new phases to BACKLOG.md. Do NOT execute any implementation -- discovery only."
elif $LOOP; then
	PROMPT=""  # Loop mode handles prompts per-cycle
else
	PROMPT="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. Continue from where the last session left off. Follow the session loop defined in CLAUDE.md."
fi

# Run a single loop cycle: check runnable phases and dispatch accordingly
# Args: $1=remaining_seconds, $2=cycle_number, $3=output_mode ("log" or "tee")
# Returns 0 to continue looping, 1 to stop
run_loop_cycle() {
	local remaining="$1"
	local cycle="$2"
	local output_mode="$3"
	local current_session
	current_session=$(get_session_num)
	local current_log="$LOG_DIR/session-${current_session}.log"
	touch "$current_log"

	local allowed_tools="Bash(description:*),Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,mcp__claude-orchestrator__*,mcp__obsidian__*"

	get_runnable_phases

	if [[ ${#RUNNABLE_PHASES[@]} -gt 1 ]]; then
		# Multiple phases -> parallel execution
		if [[ "$output_mode" == "log" ]]; then
			echo "[$(date)] Cycle $cycle: parallel execution of ${#RUNNABLE_PHASES[@]} phases (${RUNNABLE_PHASES[*]}, ${remaining}s remaining)" >> "$SESSION_LOG"
			run_parallel_phases "${RUNNABLE_PHASES[@]}" >> "$SESSION_LOG" 2>&1 || true
			merge_phase_results "${PARALLEL_PHASES[@]}" >> "$SESSION_LOG" 2>&1 || true
			echo "[$(date)] Parallel cycle $cycle finished" >> "$SESSION_LOG"
		else
			echo ""
			echo "=== Cycle $cycle: Parallel execution of phases ${RUNNABLE_PHASES[*]} ==="
			run_parallel_phases "${RUNNABLE_PHASES[@]}" 2>&1 | tee -a "$current_log" || true
			merge_phase_results "${PARALLEL_PHASES[@]}" 2>&1 | tee -a "$current_log" || true
		fi
		return 0

	elif [[ ${#RUNNABLE_PHASES[@]} -eq 1 ]]; then
		# Single phase -> sequential execution (existing behavior)
		local exec_prompt="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. Continue from where the last session left off. Follow the session loop defined in CLAUDE.md. Do NOT pause at checkpoints -- execute all phases continuously until the backlog is complete or you encounter a blocking error."
		if [[ "$output_mode" == "log" ]]; then
			echo "[$(date)] Cycle $cycle: executing phase ${RUNNABLE_PHASES[0]} (session $current_session, ${remaining}s remaining)" >> "$SESSION_LOG"
			echo "[$(date)] Starting execution session $current_session" >> "$current_log"
			run_with_timeout "$remaining" claude \
				--add-dir "$TARGET_PATH" \
				--allowedTools "$allowed_tools" \
				-p "$exec_prompt" >> "$current_log" 2>&1 || true
			echo "[$(date)] Execution session $current_session finished" >> "$SESSION_LOG"
		else
			echo ""
			echo "=== Cycle $cycle: Executing phase ${RUNNABLE_PHASES[0]} (session $current_session) ==="
			run_with_timeout "$remaining" claude \
				--add-dir "$TARGET_PATH" \
				--allowedTools "$allowed_tools" \
				-p "$exec_prompt" 2>&1 | tee "$current_log" || true
		fi
		return 0

	else
		# No runnable phases -> discovery
		local disc_prompt="Read progress.md and BACKLOG.md to understand the current state. Then read targets/$TARGET.md for target-specific context. All backlog phases should be complete. Run the Continuous Discovery loop from CLAUDE.md: audit the target repo, rank opportunities, and write 1-3 new phases to BACKLOG.md. Do NOT execute any implementation -- discovery only."
		if [[ "$output_mode" == "log" ]]; then
			echo "[$(date)] Cycle $cycle: no runnable phases, running discovery (session $current_session)" >> "$SESSION_LOG"
			echo "[$(date)] Starting discovery session $current_session" >> "$current_log"
			run_with_timeout "$remaining" claude \
				--add-dir "$TARGET_PATH" \
				--allowedTools "$allowed_tools" \
				-p "$disc_prompt" >> "$current_log" 2>&1 || true
			echo "[$(date)] Discovery session $current_session finished" >> "$SESSION_LOG"
		else
			echo ""
			echo "=== Cycle $cycle: Discovery (session $current_session) ==="
			run_with_timeout "$remaining" claude \
				--add-dir "$TARGET_PATH" \
				--allowedTools "$allowed_tools" \
				-p "$disc_prompt" 2>&1 | tee "$current_log" || true
		fi

		# After discovery, check if new work was created
		sleep 2
		get_runnable_phases
		if [[ ${#RUNNABLE_PHASES[@]} -eq 0 ]]; then
			echo "[$(date)] Discovery produced no new work. Stopping loop."
			return 1
		fi
		return 0
	fi
}

if $BACKGROUND; then
	mkdir -p "$LOG_DIR"

	(
		cd "$SCRIPT_DIR"
		LOOP_START=$(date +%s)

		if $LOOP; then
			CYCLE=0
			echo "[$(date)] Continuous loop started. Timeout: ${TIMEOUT}s, max parallel: $MAX_PARALLEL" >> "$SESSION_LOG"

			while true; do
				ELAPSED=$(( $(date +%s) - LOOP_START ))
				if [[ $ELAPSED -ge $TIMEOUT ]]; then
					echo "[$(date)] Loop timeout reached (${TIMEOUT}s). Stopping." >> "$SESSION_LOG"
					break
				fi

				REMAINING=$(( TIMEOUT - ELAPSED ))
				CYCLE=$(( CYCLE + 1 ))

				if ! run_loop_cycle "$REMAINING" "$CYCLE" "log"; then
					echo "[$(date)] Loop stopping (no new work after discovery)." >> "$SESSION_LOG"
					break
				fi

				sleep 5  # Brief pause between cycles
			done

			echo "[$(date)] Loop completed after $CYCLE cycle(s)." >> "$SESSION_LOG"
		else
			# Single session mode
			run_with_timeout "$TIMEOUT" claude \
				--add-dir "$TARGET_PATH" \
				--allowedTools "Bash(description:*),Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,mcp__claude-orchestrator__*,mcp__obsidian__*" \
				-p "$PROMPT" >> "$SESSION_LOG" 2>&1
			EXIT_CODE=$?

			if [[ $EXIT_CODE -eq 0 ]]; then
				echo "[$(date)] Session completed successfully" >> "$SESSION_LOG"
			else
				echo "[$(date)] Session exited with code $EXIT_CODE" >> "$SESSION_LOG"
			fi
		fi

		# Clean up PID file
		rm -f "$PID_FILE"
	) &

	BG_PID=$!
	echo "$BG_PID" > "$PID_FILE"
	echo "Background session started (PID $BG_PID)"
	echo "Monitor: tail -f $SESSION_LOG"
	echo "Stop: ./launcher.sh --stop"
else
	# Foreground mode
	cd "$SCRIPT_DIR"
	if $LOOP; then
		LOOP_START=$(date +%s)
		CYCLE=0
		mkdir -p "$LOG_DIR"

		while true; do
			ELAPSED=$(( $(date +%s) - LOOP_START ))
			if [[ $ELAPSED -ge $TIMEOUT ]]; then
				echo "[$(date)] Loop timeout reached (${TIMEOUT}s). Stopping."
				break
			fi

			REMAINING=$(( TIMEOUT - ELAPSED ))
			CYCLE=$(( CYCLE + 1 ))

			if ! run_loop_cycle "$REMAINING" "$CYCLE" "tee"; then
				break
			fi

			sleep 5
		done

		echo "Loop completed after $CYCLE cycle(s)."
	else
		claude "$PROMPT"
	fi
fi
