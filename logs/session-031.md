# Session 031

- **Date:** 2026-02-11
- **Target:** autonomous-dev-scheduler
- **Phases:** Discovery + 29-34
- **Outcome:** Completed

## Discovery

Deep audit via Opus subagent (read 20+ source files). Found 9 genuine issues:
1. Zombie subprocess on timeout in evaluator.py and planner.py (Medium)
2. Database single-connection shared across concurrent tasks (High - downgraded: not a real bug in asyncio single-threaded context)
3. Merge queue fetch/rebase: fetched branch lost after remote removal (Medium)
4. Green branch workspace left on wrong branch after failed merge (Medium)
5. Worker branch isolation: next unit branches from wrong base (Low)
6. Dual WorkspacePool instances in coordinator (Medium)
7. persist_session_result not actually atomic (Low)
8. Merge queue stale base ref for rebase (Medium)
9. SSH backend remote paths passed to local-only merge_to_working (Medium)

Added Phases 29-31 to BACKLOG.md. Phases 32-34 were added externally.

## Phases Executed

### Phase 29: Kill zombie subprocesses (9bebcd8)
- evaluator.py: Added proc.kill() + await proc.wait() in TimeoutError handler
- planner.py: Same pattern
- Updated test_evaluator.py to verify kill called
- Added timeout test to test_planner.py

### Phase 30: DB atomicity (93c44e3)
- persist_session_result now uses single transaction with rollback
- Added test for atomic rollback on constraint violation

### Phase 31: Merge queue fetch/rebase (8b57ab8)
- _fetch_worker_branch: Creates local branch from FETCH_HEAD before removing remote
- _rebase_onto_base: Fetches origin before rebase to ensure fresh base ref
- Added 3 tests: branch creation, fetch failure, rebase order

### Phase 32: Scheduler regression detection (09a7383)
- Moved get_latest_snapshot() BEFORE insert_snapshot() so previous != before
- _parse_pytest: Errors now count toward test_failed
- Added scheduler snapshot ordering test and errors-only test

### Phase 33: Parsing, recovery, output (e5ff852)
- _parse_mypy: Anchored regex to avoid false positives from pytest output
- snapshot_project_health: Now calls _parse_bandit
- LocalBackend.spawn(): Clears _stdout_collected for reused workers
- DB: Added asyncio.Lock + locked_call() for concurrent access
- recover_stale_units: Increments attempt counter
- Added tests for mypy false positives, concurrent claims, stale recovery

### Phase 34: Green branch timeouts, rebase cleanup (f6d1add)
- _run_claude: asyncio.wait_for + proc.kill on timeout
- _run_command: asyncio.wait_for + proc.kill on timeout
- merge_queue _rebase_onto_base: Checkout base branch after rebase abort
- Added timeout tests for both _run_claude and _run_command

## Stats
- 6 commits, 15 files modified
- ~440 insertions, ~20 deletions
