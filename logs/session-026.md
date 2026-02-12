# Session 026 - Discovery + Phases 26-28

- **Date:** 2026-02-11
- **Target:** autonomous-dev-scheduler
- **Phases:** Discovery, 26, 27, 28
- **Outcome:** Completed

## Verification of Prior Session

- Fixed 2 ruff lint errors from phases 23-25 (import sorting in test_green_branch.py, line length in test_recursive_planner.py)
- Commit: d893af7
- 400 tests pass, ruff clean, mypy clean

## Discovery

Deep code audit via Opus subagent (read all 18 key source files). Found 15 genuine issues:

| Severity | Count | Key Findings |
|----------|-------|-------------|
| Critical | 1 | SQLite shared connection in async context (deferred - requires architectural change) |
| High | 3 | SSH command injection, SSH output truncation, silently swallowed gather exceptions |
| Medium | 8 | Green branch promotion, merge workspace state, branch leaks, workspace leak, wrong timeout, json parser, zombie subprocess, duplicate pools |
| Low | 2 | Workspace release error handling, git remote leaks |

Selected top 3 groups for immediate phases (26-28). Remaining findings documented for future discovery cycles.

## Phase 26: SSH Backend Command Injection + Output Truncation

- Added `shlex.quote()` on all SSH command arguments to prevent shell injection
- Added output buffering (`_stdout_bufs`, `_stdout_collected`) matching LocalBackend pattern
- Added cleanup of buffers in `cleanup()` method
- 2 new tests: shell metacharacter injection prevention, consistent output on repeated calls
- Commit: 3c7f3a1

## Phase 27: Gather Exception Logging + Green Branch Merge Check

- Captured `asyncio.gather` return value and logged `BaseException` instances with full tracebacks
- Checked return value of `git merge --ff-only` in both promotion paths (direct and fixup loop)
- Returns `FixupResult(promoted=False)` when merge fails instead of falsely reporting success
- 3 new tests: gather exception logging via caplog, ff-only merge failure in direct path, ff-only merge failure in fixup loop
- Commit: d64726b

## Phase 28: Zombie Subprocess + JSON Backslash + Remote Leaks

- Added `proc.kill()` + `await proc.wait()` in state.py `_run_command` TimeoutError handler
- Fixed json_utils `_find_balanced` to only treat backslash as escape when inside strings
- Added `remote remove` after fetch in merge_queue `_fetch_worker_branch`
- 3 new tests: timeout subprocess cleanup, backslash outside JSON strings, remote cleanup after fetch
- Commit: 9986c94

## Stats

- Tests: 400 -> 409 (9 new)
- Files modified: 12
- All checks pass: pytest, ruff, mypy
