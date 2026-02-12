# self-driving-dev

Autonomous session harness for Claude Code. Each session reads a backlog, picks the next unblocked task, implements it in a target repo, verifies, commits, and updates progress.

## Session Loop

Every Claude Code session in this repo MUST follow this loop:

1. Read `progress.md` to understand current state
2. Read `BACKLOG.md` to find the next unblocked phase
3. Read `targets/<target>.md` to load target-specific context (repo path, constraints, verification)
4. Implement the phase in the target repo
5. Run verification in the target repo (per target's verification requirements)
6. Commit in the target repo
7. Update `progress.md` with outcome (phase completed, commit hash, summary)
8. If the next phase has `checkpoint: true`: stop and notify via Telegram
9. Otherwise: continue to the next phase

## Rules

- NEVER skip reading progress.md and BACKLOG.md at session start
- NEVER modify BACKLOG.md during execution -- it is the plan of record
- progress.md Current State MUST be rewritten (not appended) each phase
- When all backlog phases are done, progress.md MUST contain the phrase "all phases complete" -- this is the signal that triggers discovery mode
- Session logs go in `logs/session-NNN.md` after each session completes
- If blocked: update progress.md Blocked field, notify via Telegram, stop

## Verification

Verification requirements are defined per-target in `targets/<target>.md`. The target's verification suite MUST pass before committing in the target repo.

## Checkpoints

Phases marked `checkpoint: true` in BACKLOG.md pause for human review. At a checkpoint:
1. Update progress.md with what was completed
2. Send Telegram notification with summary and next steps
3. Stop and wait for the next session to be launched

## Session Logs

After each session, write a log to `logs/session-NNN.md` with:
- Date, target repo, phases attempted
- Outcome (completed/blocked/partial)
- Commit hashes
- Issues encountered
- Time spent (approximate)

## Background Execution

The launcher supports background mode for fire-and-forget sessions:

```bash
./launcher.sh --background                    # Run in background (1 hour timeout)
./launcher.sh --background --timeout 7200     # Custom timeout (2 hours)
./launcher.sh --stop                          # Kill running background session
tail -f logs/session-NNN.log                  # Monitor live output
```

Background sessions:
- Log all output to `logs/session-NNN.log`
- Write PID to `.session.pid` for kill switch
- Auto-terminate after timeout (default: 3600s)
- Clean up PID file on exit (normal, timeout, or error)
- Resume works automatically -- next launch reads progress.md

## Parallel Phase Execution

When `--loop` mode finds multiple runnable phases (no unmet dependencies), it launches them in parallel using git worktrees:

```bash
MAX_PARALLEL=3 ./launcher.sh --loop --background    # Default: 3 parallel agents
MAX_PARALLEL=5 ./launcher.sh --loop --background    # Override to 5
./launcher.sh --dry-run --loop                       # Preview runnable phases
```

### How It Works

1. **Dependency parsing**: Reads `BACKLOG.md` for `**Dependencies:**` lines, builds a DAG
2. **Runnable detection**: Phases with no unmet deps and not yet completed are runnable
3. **Worktree isolation**: Each agent gets `<target>/.worktrees/phase-N/` with its own branch
4. **Parallel execution**: Up to `MAX_PARALLEL` (default 3) `claude -p` processes run concurrently
5. **Sequential merge**: Results merge back to main one at a time, with conflict detection and verification
6. **Cleanup**: Worktrees and branches are removed after merge

### `.phase-result.json` Contract

Each parallel agent writes this file to the worktree root after completing:

```json
{"status": "success", "summary": "Brief description of changes"}
```

Or on failure:

```json
{"status": "failed", "summary": "What went wrong"}
```

### `.worktrees/` Directory

Created in the target repo during parallel execution. Contains one subdirectory per phase (`phase-N/`). Each worktree gets a symlinked `.venv` from the main repo. Cleaned up automatically after merge. Should be added to `.gitignore` in target repos.

### Fallback Behavior

- If only 1 phase is runnable: runs sequentially (existing behavior)
- If worktree creation fails: skips that phase, continues with others
- If merge has conflicts: aborts merge for that phase, retries next cycle
- If verification fails after merge: reverts merge, marks phase as failed

## Continuous Discovery

When all backlog phases are complete (no unblocked phases remain), switch to discovery mode instead of stopping:

### Discovery Session Loop

1. Confirm all phases in BACKLOG.md are complete (check progress.md)
2. Run structured analysis via claude-orchestrator MCP tools:
   a. Call `analyze_codebase_tool(project_path)` -- returns CodebaseAnalysis JSON with metrics, module info, and identified gaps
   b. Call `research_best_practices_tool(gaps_json, project_type)` -- takes the `gaps` array from step (a) and returns ranked GapReports with impact/effort scores
   c. Call `generate_improvement_proposals_tool(gap_reports_json, max_proposals=3, target_name=<target>, start_phase=<next>)` -- converts gap reports into BACKLOG.md-ready phases with goals, tasks, and verification criteria
3. Write the generated proposals to BACKLOG.md:
   - Use the `backlog_markdown` field from the proposals tool output
   - Every generated phase has `checkpoint: true` (discovery is advisory, not autonomous)
   - Max 3 new phases per discovery session
4. Update progress.md: set Phase to `Discovery complete -- new phases added` and clear the "all phases complete" text (this signals the launcher to resume execution mode)
5. Send Telegram notification with discovery summary
6. Stop and wait for human review of the new backlog phases

**Fallback**: If MCP tools are unavailable (server not running), fall back to manual audit:
   - Run the verification suite (target-specific commands)
   - Read recent git log (last 10 commits) for context
   - Scan for TODOs/FIXMEs in source files
   - Rank findings manually and write phases to BACKLOG.md

### Discovery Constraints

- Discovery phases are ALWAYS `checkpoint: true` -- never auto-execute discovered work
- Max 3 new phases per discovery session to prevent scope creep
- Prioritize regressions and bugs over features and dependencies
- If verification suite is failing, the first discovered phase MUST fix it
- Discovery does NOT modify code -- it only writes to BACKLOG.md and progress.md

### --discover Flag

When launched with `--discover`, run ONLY the discovery loop (skip normal execution).
Useful for periodic audits without executing any backlog work.

## Autonomy Boundaries

- Default iteration limit: 5 attempts on a failing approach, then escalate
- Phase completion: git commit at each phase in the target repo
- Stop for errors that truly require human judgment
- Scope changes require updating BACKLOG.md (which requires human approval)
