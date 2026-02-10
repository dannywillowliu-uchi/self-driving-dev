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

## Continuous Discovery

When all backlog phases are complete (no unblocked phases remain), switch to discovery mode instead of stopping:

### Discovery Session Loop

1. Confirm all phases in BACKLOG.md are complete (check progress.md)
2. Audit the target repo:
   - Run the verification suite (`run_verification` or target-specific commands)
   - Read recent git log (last 10 commits) for context
   - Scan for TODOs/FIXMEs in source files
   - Check for outdated dependencies if applicable
3. Rank discovered opportunities by priority:
   - **Regressions** (broken tests, new lint errors) -- highest priority
   - **Bugs** (TODO/FIXME markers with severity hints)
   - **Code quality** (refactoring opportunities, test coverage gaps)
   - **Features** (enhancements surfaced during audit)
   - **Dependencies** (outdated packages, security advisories) -- lowest priority
4. Write the top 1-3 opportunities as new phases in BACKLOG.md:
   - Every new phase MUST have `checkpoint: true` (discovery is advisory, not autonomous)
   - Include clear problem statement and verification criteria
   - Max 3 new phases per discovery session
5. Update progress.md: `Phase: Discovery complete`, list what was found
6. Send Telegram notification with discovery summary
7. Stop and wait for human review of the new backlog phases

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
