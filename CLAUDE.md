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

## Autonomy Boundaries

- Default iteration limit: 5 attempts on a failing approach, then escalate
- Phase completion: git commit at each phase in the target repo
- Stop for errors that truly require human judgment
- Scope changes require updating BACKLOG.md (which requires human approval)
