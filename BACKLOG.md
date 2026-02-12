# Backlog

Target: `autonomous-dev-scheduler`

Each phase is a self-contained unit of work. Phases are executed in order unless dependencies say otherwise. Phases marked `checkpoint: true` pause for human review before the next session continues.

---

## Phase 8: Fix plan tree persistence + update stale CLAUDE.md

**Goal:** The recursive planner creates plan trees but they aren't persisted to the database after execution. Also, CLAUDE.md references `uv run` which doesn't work -- needs to say `.venv/bin/python -m`.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Add plan_tree serialization to round_controller after planner runs
2. Update CLAUDE.md verification commands from `uv run` to `.venv/bin/python -m`
3. Add test for plan tree persistence round-trip
4. Verify existing tests still pass

### Verification

- Plan tree saved to DB and retrievable
- CLAUDE.md has correct commands
- All 293+ tests pass

---

## Phase 9: Add subprocess timeouts to evaluator/planner

**Goal:** The evaluator and planner shell out to subprocess but have no timeout, risking hung sessions.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Add configurable timeout parameter to evaluator subprocess calls
2. Add configurable timeout to planner subprocess calls
3. Handle TimeoutExpired with clean error propagation
4. Add tests for timeout behavior

### Verification

- Subprocess calls have timeouts
- TimeoutExpired handled gracefully
- All tests pass

---

## Phase 10: JSON parsing robustness

**Goal:** Multiple modules parse JSON from LLM output but fail hard on malformed responses. Add fallback parsing.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Audit all json.loads calls for LLM output parsing
2. Add extract_json_from_text helper that strips markdown fences and finds JSON
3. Replace raw json.loads with robust parser where appropriate
4. Add tests for malformed JSON recovery

### Verification

- JSON parsing recovers from markdown-wrapped responses
- Existing tests pass

---

## Phase 11: Green branch fixup graceful degradation

**Goal:** Green branch fixup currently fails hard if the fix attempt doesn't compile/pass. Should gracefully fall back to the original code.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Add try/except around fixup application
2. On failure, restore original state and log warning
3. Add configurable max fixup attempts
4. Add tests for fixup failure recovery

### Verification

- Failed fixups don't crash the pipeline
- Original code preserved on failure

---

## Phase 12: Integration tests for concurrent workspace pool

**Goal:** The workspace pool manages concurrent git worktrees but lacks integration tests for race conditions and cleanup.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Add integration test for concurrent workspace checkout
2. Test workspace cleanup after failures
3. Test workspace pool exhaustion handling
4. Add stress test for rapid acquire/release cycles

### Verification

- All integration tests pass
- No resource leaks detected

---

## Phase 13: Extract hardcoded config values

**Goal:** Several modules have hardcoded values (max retries, timeouts, paths) that should come from config.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** Phase 9

### Tasks

1. Audit source for hardcoded config-like values
2. Add new config fields to config.py
3. Thread config through to callsites
4. Add tests for config override behavior

### Verification

- No hardcoded config values in core modules
- Config overrides work

---

## Phase 14: Structured logging and metrics

**Goal:** Add structured logging throughout the pipeline for observability and debugging.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Add structured logger setup with JSON output option
2. Add logging to round_controller, evaluator, planner
3. Add basic metrics collection (round duration, test pass rate, fix attempts)
4. Add log level configuration

### Verification

- Key operations logged with structured data
- Metrics accessible after round completion

---

## Phase 15: Per-unit timeout and verification overrides

**Goal:** Allow individual work units to specify custom timeouts and verification commands, overriding global defaults.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** Phase 13

### Tasks

1. Add timeout and verification_command fields to WorkUnit model
2. Update worker to use per-unit values when present
3. Update round_controller to pass overrides through
4. Add tests for override precedence

### Verification

- Per-unit overrides take precedence over global config
- Defaults still work when overrides absent

---

## Phase 16: Narrow exception handlers in orchestration modules

**Goal:** Replace broad `except Exception` handlers with specific exception types in round_controller.py and coordinator.py. Broad catches mask bugs and make debugging harder.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Audit `src/mission_control/round_controller.py` for broad exception handlers and replace with specific types (e.g., `asyncio.TimeoutError`, `RuntimeError`, `OSError`)
2. Audit `src/mission_control/coordinator.py` for broad exception handlers and replace with specific types
3. Add structured logging context to each exception handler
4. Verify no regressions in error handling behavior

### Verification

- No broad `except Exception:` handlers remain in round_controller.py and coordinator.py
- Error messages include context information
- All tests pass, ruff clean

---

## Phase 17: Test coverage for backend modules and models

**Goal:** Add unit tests for untested modules: models.py (SnapshotDelta properties, computed fields), and backend implementations (ssh.py, local.py, container.py).

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Create `tests/test_models.py` with tests for SnapshotDelta.improved/regressed, WorkUnit defaults, and model edge cases
2. Add SSH backend unit tests (mock asyncio.create_subprocess_exec for remote commands)
3. Add local backend unit tests (workspace provisioning, clone management)
4. Add container backend unit tests (mock Docker API calls)
5. Verify test-to-code ratio remains above 0.9

### Verification

- New test files created for previously untested modules
- All tests pass
- Test-to-code ratio improved

---

## Phase 18: Resolve TODO/FIXME markers in discovery.py

**Goal:** Address the TODO/FIXME markers in discovery.py that indicate unfinished discovery strategies and edge case handling.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Read all TODO/FIXME markers in `src/mission_control/discovery.py` and `tests/test_discovery.py`
2. Implement or remove each marker with a clear decision (implement if valuable, remove if obsolete)
3. Add tests for any newly implemented functionality
4. Clean up corresponding test TODOs

### Verification

- No TODO/FIXME markers remain in discovery.py
- All tests pass
- Ruff clean

---

## Phase 19: DRY up duplicate handoff parsing and fix import placement

**Goal:** Remove duplicate handoff-building logic in worker.py (two functions extract the same fields from MC_RESULT dicts) and move the misplaced `import json` in state.py to module level.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Refactor `src/mission_control/worker.py`: have `parse_handoff()` delegate to `_parse_handoff()` instead of duplicating field extraction logic
2. Move `import json` from inside `snapshot_project_health()` to module level in `src/mission_control/state.py`
3. Verify existing tests pass and ruff is clean

### Verification

- No duplicate field extraction code in worker.py
- `import json` at module level in state.py
- All tests pass, ruff clean

---

## Phase 20: Split db.py into focused modules

**Goal:** Refactor the 922-line db.py into smaller, focused modules grouped by domain (session/snapshot operations, plan/work-unit operations, mission/round operations).

**Status:** Not started
**Checkpoint:** true
**Dependencies:** Phase 19

### Tasks

1. Identify natural groupings in db.py methods by model domain
2. Extract session/snapshot/task/decision CRUD into `db_sessions.py`
3. Extract plan/work-unit/merge-request CRUD into `db_plans.py`
4. Extract mission/round/handoff CRUD into `db_missions.py`
5. Keep `db.py` as the facade that composes the sub-modules (public API unchanged)
6. Update imports across the codebase (should be no changes needed if facade pattern used)
7. Ensure all 300+ tests pass

### Verification

- No individual db module exceeds 400 LOC
- db.py public API unchanged (all callers work without modification)
- All tests pass, ruff clean

---

## Phase 21: Fix command injection in green_branch.py fixup agent

**Goal:** The fixup agent prompt (containing raw verification output) is interpolated directly into a shell command string passed to `create_subprocess_shell`. This is a command injection vulnerability -- verification output could contain shell metacharacters that execute arbitrary commands.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Refactor `green_branch.py:run_fixup()` to pass the prompt via stdin to the `claude` subprocess instead of embedding it in the shell command string
2. Switch from `create_subprocess_shell` to `create_subprocess_exec` with an argument list for the claude invocation
3. Add test for prompt with shell metacharacters (quotes, backticks, $()) to verify no injection
4. Verify existing green_branch tests still pass

### Verification

- Fixup prompt passed via stdin, not command line
- No shell string interpolation of untrusted data
- All tests pass, ruff clean

---

## Phase 22: Log git/subprocess failures and fix regex backtracking

**Goal:** Multiple modules silently swallow subprocess failures, making debugging difficult. Also, json_utils.py uses greedy regex patterns that can cause catastrophic backtracking on large inputs.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `worker.py:_execute_unit()` (lines 329-330), log warnings when git cleanup operations fail, including the git error output
2. In `workspace.py:_create_clone()` (line 103), include the captured git output in the error log message
3. In `json_utils.py` (lines 50, 52), replace greedy `[\s\S]*` with non-greedy `[\s\S]*?` to prevent catastrophic backtracking
4. Add tests for json_utils with large/malformed inputs to verify no hanging
5. Verify all existing tests pass

### Verification

- Git failures logged with output context
- Regex patterns use non-greedy quantifiers
- All tests pass, ruff clean

---

## Phase 23: Fix shell injection in recursive_planner.py + zombie process leak

**Goal:** The recursive planner passes LLM-derived content (node.scope, objective) directly into a shell command string via `create_subprocess_shell`, exactly the same class of bug fixed in green_branch.py (Phase 21). Also, session.py catches TimeoutError but never kills the subprocess, leaving zombie Claude sessions running indefinitely.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Refactor `src/mission_control/recursive_planner.py` (line 175-185): Switch from `create_subprocess_shell` with string interpolation to `create_subprocess_exec` with the prompt passed via stdin (matching the pattern in `green_branch.py:_run_claude`)
2. Add test for recursive planner with shell metacharacters in scope/objective to verify no injection
3. Fix `src/mission_control/session.py` (line 193-197): Add `proc.kill()` and `await proc.wait()` in the TimeoutError handler before returning
4. Add test for session timeout process cleanup
5. Verify all existing tests pass

### Verification

- Planner prompt passed via stdin, not command line
- No shell string interpolation of untrusted data in recursive_planner.py
- Timed-out session processes are killed
- All tests pass, ruff clean

---

## Phase 24: Fix LocalBackend output truncation + green branch merge race condition

**Goal:** LocalBackend.get_output has a logic error where the final stdout read for completed processes never executes (the buffer key always exists since it's initialized to `b""` at spawn time, so the `not in` check is always False). Also, GreenBranchManager.merge_to_working operates on a shared workspace directory without serialization -- concurrent calls from asyncio.gather interleave git operations, potentially corrupting git state.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Fix `src/mission_control/backends/local.py` get_output (line 95): Replace the `not in` dict check with a proper "collected" flag or always read remaining stdout when process is finished
2. Add test verifying complete output is captured from finished processes
3. Add `asyncio.Lock` to `src/mission_control/green_branch.py` to serialize `merge_to_working` calls, preventing concurrent git operations on the shared workspace
4. Add test for concurrent merge_to_working calls
5. Verify all existing tests pass

### Verification

- Completed process output is fully captured (no truncation)
- Concurrent merge_to_working calls are serialized via lock
- All tests pass, ruff clean

---

## Phase 25: Fix attempt counter, off-by-one in round limit, multiline MC_RESULT parsing

**Goal:** Three logic errors: (1) RoundController._execute_single_unit never increments unit.attempt on failure, so failed units never reach max_attempts and retry forever. (2) _should_stop checks mission.total_rounds before it's updated for the current round, causing max_rounds+1 rounds to execute. (3) parse_mc_result regex only matches JSON on a single line, failing for pretty-printed MC_RESULT output.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Add `unit.attempt += 1` to all failure paths in `src/mission_control/round_controller.py:_execute_single_unit` (lines 320-442)
2. Fix `_should_stop` (line 466-481): Check `round_number` parameter instead of `mission.total_rounds`, or update `mission.total_rounds` before calling `_should_stop`
3. Refactor `src/mission_control/session.py:parse_mc_result` (line 63-73): Use `json_utils.extract_json` or a multiline-capable approach instead of the single-line regex
4. Add tests for each fix: attempt counter incremented on failure, correct round limit enforcement, multiline MC_RESULT parsing
5. Verify all existing tests pass

### Verification

- Failed units have attempt counter incremented
- Round loop stops at exactly max_rounds (not max_rounds+1)
- MC_RESULT parsing handles multiline JSON output
- All tests pass, ruff clean

---

## Phase 26: Fix SSH backend command injection and output truncation

**Goal:** Two issues in the SSH backend: (1) `spawn()` concatenates command arguments (including LLM-derived prompts) into a shell string passed to SSH, creating a command injection vulnerability identical to the one fixed in green_branch.py and recursive_planner.py. (2) `get_output()` reads from `proc.stdout.read()` without buffering, so a second call returns empty string -- the same class of bug fixed in LocalBackend.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Refactor `src/mission_control/backends/ssh.py:spawn()` (line 80): Use `shlex.quote()` on command elements, or pass the prompt via stdin to the remote command (matching the pattern used in green_branch.py `_run_claude`)
2. Add output buffering to `SSHBackend.get_output()` matching the `_stdout_collected` pattern in LocalBackend: buffer remaining stdout on first read, return buffer on subsequent reads
3. Add test for SSH spawn with shell metacharacters in command to verify no injection
4. Add test verifying SSH get_output returns consistent data on multiple calls
5. Verify all existing tests pass

### Verification

- SSH commands use shlex.quote or stdin for untrusted input
- get_output returns consistent results on repeated calls
- All tests pass, ruff clean

---

## Phase 27: Fix silent exception swallowing in asyncio.gather and green branch promotion

**Goal:** Two correctness issues: (1) `RoundController._execute_units` uses `asyncio.gather(*tasks, return_exceptions=True)` but discards the return value, silently swallowing any unhandled exceptions from unit execution. Failed units remain in "running" status forever. (2) `GreenBranchManager.run_fixup` ignores the return value of `git merge --ff-only` -- if the merge fails, it still returns `FixupResult(promoted=True)`, reporting success when the green branch was not actually updated.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py` (line 301): Capture the result of `asyncio.gather`, iterate over results, and log any `BaseException` instances as errors
2. In `src/mission_control/green_branch.py` (line 96): Capture the return value of `_run_git("merge", "--ff-only", ...)`. If the merge fails, log an error and return `FixupResult(promoted=False, failure_output="ff-only merge failed")`
3. Apply the same fix to the promotion merge inside the fixup loop (around line 131)
4. Add test for gather exception logging
5. Add test for promotion failure when ff-only merge fails
6. Verify all existing tests pass

### Verification

- Unhandled exceptions from asyncio.gather are logged, not silently swallowed
- Failed ff-only merges return promoted=False
- All tests pass, ruff clean

---

## Phase 28: Fix zombie subprocess in state.py, json_utils backslash bug, and merge queue remote leaks

**Goal:** Three resource/correctness issues: (1) `state.py:_run_command` catches `asyncio.TimeoutError` but never kills the subprocess, leaving zombie processes running indefinitely. (2) `json_utils.py:_find_balanced` treats backslash as an escape character even outside JSON strings, causing incorrect brace depth tracking when LLM output contains file paths with backslashes. (3) `merge_queue.py:_fetch_worker_branch` adds git remotes but never removes them, accumulating stale remotes over the merge queue's lifetime.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/state.py` (line 77-78): Add `proc.kill()` and `await proc.wait()` in the TimeoutError handler before returning, matching the pattern in session.py
2. In `src/mission_control/json_utils.py` (line 23-26): Change backslash handling to only set escape flag when inside a string: replace `if ch == "\\":` block with `if ch == "\\" and in_string: escape = True; continue`
3. In `src/mission_control/merge_queue.py` (line 108-113): Add `await self._run_git("remote", "remove", remote_name)` after the fetch completes, matching the cleanup pattern in green_branch.py
4. Add test for state.py timeout subprocess cleanup
5. Add test for json_utils with backslashes outside JSON strings
6. Add test for merge queue remote cleanup after fetch
7. Verify all existing tests pass

### Verification

- Timed-out subprocesses in state.py are killed
- Backslashes outside JSON strings don't affect brace depth tracking
- Git remotes are cleaned up after merge queue fetch
- All tests pass, ruff clean

---

## Phase 29: Kill zombie subprocesses on timeout in evaluator.py and planner.py

**Goal:** Both `evaluator.py` and `planner.py` catch `asyncio.TimeoutError` from `wait_for(proc.communicate())` but never call `proc.kill()`, leaving orphaned `claude` processes running indefinitely. This is the same class of bug fixed in `session.py`, `state.py`, and `recursive_planner.py` but was missed in these two modules.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/evaluator.py` (line 120-122): Add `proc.kill()` and `await proc.wait()` before the `return ObjectiveEvaluation()` in the `except asyncio.TimeoutError` handler
2. In `src/mission_control/planner.py` (line 107-109): Add `proc.kill()` and `await proc.wait()` before setting `output = ""` in the `except asyncio.TimeoutError` handler
3. Add tests for both timeout handlers verifying the subprocess is killed
4. Verify all existing tests pass

### Verification

- Timed-out evaluator and planner subprocesses are killed via `proc.kill()`
- All tests pass, ruff clean

---

## Phase 30: Add asyncio.Lock to Database for concurrent access safety

**Goal:** The `Database` class creates a single `sqlite3.Connection` used by multiple concurrent asyncio tasks (workers, merge queue, monitor) without any serialization. Interleaved `execute()`/`commit()` calls from different tasks can corrupt state or cause `OperationalError`. Add an `asyncio.Lock` to serialize database access.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Add an `asyncio.Lock` attribute to the `Database.__init__` method
2. Add an `async with self._lock:` context manager wrapper method (e.g., `async def execute_atomic(self, fn)`) or make the key mutating methods async-safe
3. Since db methods are synchronous (they use `sqlite3` directly), wrap critical mutating methods (`claim_work_unit`, `update_work_unit`, `update_heartbeat`, `insert_session`, `persist_session_result`) with lock acquisition
4. Also fix `persist_session_result` to use a single transaction (no intermediate commits) for atomicity
5. Add test for concurrent db access from multiple asyncio tasks
6. Verify all existing tests pass

### Verification

- Database methods that mutate state are serialized via asyncio.Lock
- `persist_session_result` commits atomically in a single transaction
- Concurrent db operations from multiple tasks do not interleave
- All tests pass, ruff clean

---

## Phase 31: Fix merge queue branch checkout after remote removal and stale base rebase

**Goal:** Two issues in `merge_queue.py`: (1) `_fetch_worker_branch` removes the git remote after fetching, but the fetched branch only exists as `FETCH_HEAD`, not as a local branch. The subsequent `_rebase_onto_base` tries to `git checkout mr.branch_name` which fails because no local branch with that name was created. Fix by creating a local branch from `FETCH_HEAD` before removing the remote. (2) `_rebase_onto_base` rebases against `origin/{branch}` without first running `git fetch origin`, so the base ref may be stale if other merge requests were already merged.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `_fetch_worker_branch` (line 112-114): After `git fetch`, create a local branch from `FETCH_HEAD` via `git branch mr.branch_name FETCH_HEAD` before removing the remote
2. In `_process_next` or `_rebase_onto_base`: Add `git fetch origin` before the rebase to ensure `origin/{branch}` is up to date
3. Add test for fetch + local branch creation workflow
4. Add test for rebase against freshly fetched origin
5. Verify all existing tests pass

### Verification

- Fetched branches exist as local branches after remote removal
- Rebase is performed against a fresh `origin/{branch}` ref
- All tests pass, ruff clean

---

## Phase 32: Fix scheduler regression detection and test error counting

**Goal:** Two bugs make the scheduler unable to detect regressions: (1) `scheduler.py` calls `db.get_latest_snapshot()` after inserting the `before` snapshot, so `previous == before` and `SnapshotDelta` always shows zero change. Regression detection is completely broken. (2) `_parse_pytest` in `state.py` counts pytest errors (collection errors, fixture errors) in `test_total` but not in `test_failed`, so error-only failures go undetected by discovery -- `test_failed` stays 0 even when tests error.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/scheduler.py` (line 59): Move `previous = self.db.get_latest_snapshot()` BEFORE `self.db.insert_snapshot(before)` (line 55) so the previous snapshot is the one from the prior run, not the one just inserted
2. In `src/mission_control/state.py` `_parse_pytest` (line 28-33): Include errors in `test_failed` count: `failed = failed_count + errors_count`
3. Add test for scheduler: verify that `previous` and `before` are different snapshots (from different runs)
4. Add test for `_parse_pytest`: verify output with errors but no failures still has nonzero `test_failed`
5. Verify all existing tests pass

### Verification

- `previous` snapshot is from the prior run, not the just-inserted `before`
- Pytest errors are included in `test_failed` count
- All tests pass, ruff clean

---

## Phase 33: Fix cross-contaminated output parsing, stale recovery attempt counter, and LocalBackend output loss

**Goal:** Three data integrity bugs: (1) `snapshot_project_health` in `state.py` runs all parsers (`_parse_pytest`, `_parse_ruff`, `_parse_mypy`) on the combined verification command output, so pytest tracebacks containing `"error:"` inflate mypy error counts and ruff-format lines inflate pytest counts. `_parse_bandit` is never called at all. (2) `db.recover_stale_units` resets status to `pending` but doesn't increment `attempt`, so units that crash workers before updating the DB retry infinitely. (3) `LocalBackend.spawn()` resets `_stdout_bufs` but not `_stdout_collected`, so a worker reused for a second unit never collects remaining stdout from the new process.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/state.py` `_parse_mypy`: Change the `"error:"` match to use mypy-specific format `r"^\S+\.py:\d+: error:"` (anchored regex matching `file.py:line: error:`) to avoid false positives from pytest tracebacks
2. In `src/mission_control/state.py` `snapshot_project_health`: Call `_parse_bandit` on the output and include security findings in the snapshot
3. In `src/mission_control/db.py` `recover_stale_units` (line 602): Add `attempt = attempt + 1` to the UPDATE SQL so recovered units count toward max_attempts
4. In `src/mission_control/backends/local.py` `spawn()` (after line 65): Add `self._stdout_collected.discard(worker_id)` to clear the collected flag when reusing a worker
5. Add test for `_parse_mypy` with combined pytest+mypy output verifying no false positives
6. Add test for `recover_stale_units` verifying attempt counter is incremented
7. Add test for LocalBackend: spawn two units on the same worker, verify both produce output
8. Verify all existing tests pass

### Verification

- `_parse_mypy` only counts lines matching mypy format, not pytest tracebacks
- `_parse_bandit` is called and security_findings is populated
- Stale-recovered units have incremented attempt counter
- LocalBackend workers produce output for all units, not just the first
- All tests pass, ruff clean

---

## Phase 34: Add timeouts to green_branch _run_claude and _run_command, fix rebase branch cleanup

**Goal:** Three robustness issues: (1) `green_branch.py` `_run_claude()` has no timeout on `proc.communicate()` -- if Claude hangs (network, API outage), the fixup agent blocks indefinitely. (2) `_run_command()` similarly has no timeout, so hung verification commands block forever. (3) `merge_queue.py` `_rebase_onto_base()` aborts on rebase failure but leaves the workspace checked out on `mr.branch_name` instead of returning to the base branch, corrupting state for the next merge request.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/green_branch.py` `_run_claude` (line 201): Wrap `proc.communicate(input=...)` in `asyncio.wait_for(..., timeout=self.config.scheduler.session_timeout)` with proc.kill+wait on timeout
2. In `src/mission_control/green_branch.py` `_run_command` (line 213): Wrap `proc.communicate()` in `asyncio.wait_for(..., timeout=self.config.target.verification.timeout)` with proc.kill+wait on timeout
3. In `src/mission_control/merge_queue.py` `_rebase_onto_base` (line 122): After `rebase --abort`, add `await self._run_git("checkout", self.config.target.branch)` to return workspace to base branch
4. Add test for `_run_claude` timeout and subprocess cleanup
5. Add test for `_run_command` timeout and subprocess cleanup
6. Add test for `_rebase_onto_base` failure: verify workspace is on base branch after abort
7. Verify all existing tests pass

### Verification

- `_run_claude` has timeout and kills subprocess on timeout
- `_run_command` has timeout and kills subprocess on timeout
- After rebase abort, workspace is checked out to base branch
- All tests pass, ruff clean

---

## Phase 35: Narrow transaction rollback exception handler in db.py

**Goal:** Replace the broad `except Exception` in `persist_session_result` (db.py:474) with specific SQLite exception types. The current handler catches all exceptions for transaction rollback and re-raises -- while this is a valid safety pattern, narrowing the catch clause to `sqlite3.Error` (the base class for all SQLite exceptions) would be more precise while preserving the rollback-and-reraise behavior.

**Status:** Not started
**Checkpoint:** true
**Priority:** low
**Dependencies:** None

### Tasks

1. In `src/mission_control/db.py:474`, replace `except Exception:` with `except sqlite3.Error:` to narrow the catch clause while still covering all SQLite-related failures (IntegrityError, OperationalError, DatabaseError, etc.)
2. Verify that `sqlite3` is already imported (it is)
3. Add a test that verifies rollback occurs on a deliberate integrity violation in `persist_session_result`
4. Verify all existing tests pass

### Verification

- No broad `except Exception:` handlers remain in db.py
- Transaction rollback still occurs on SQLite errors
- All tests pass, ruff clean

### Notes

- This is a low-priority cosmetic improvement. The existing pattern (catch-rollback-reraise) is correct and idiomatic. The change narrows the type for code clarity only.
- Session 020 previously decided that splitting db.py into sub-modules is over-engineering. That finding still holds.

---

## Phase 36: Fix merge queue before/after snapshot comparison (both taken on feature branch)

**Goal:** The merge queue's verification is comparing the feature branch to itself instead of comparing feature vs base. After `_rebase_onto_base`, the workspace is on `mr.branch_name`. The "before" snapshot (line 60) is taken on the feature branch, then `checkout mr.branch_name` (line 63) is a no-op, and the "after" snapshot (line 64) is taken on the same branch. The resulting `SnapshotDelta` always shows zero change, making the merge queue accept or reject based on absolute metrics rather than relative improvement. A feature branch that introduces regressions will show "neutral" and be merged.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/merge_queue.py` `_process_merge_request` (lines 59-64): Take the "before" snapshot on the base branch before checking out the feature branch:
   - After successful rebase, `checkout self.config.target.branch`
   - Take `before = snapshot_project_health(...)` on base
   - Then `checkout mr.branch_name`
   - Take `after = snapshot_project_health(...)` on feature branch
2. Add test: create a merge request where the feature branch has more test failures than base -- verify the reviewer returns "hurt" verdict (not "neutral")
3. Add test: verify that "before" and "after" snapshots have different test counts when the feature branch modifies test behavior
4. Verify all existing tests pass

### Verification

- "Before" snapshot taken on base branch, "after" on feature branch
- Merge queue correctly detects regressions (rejects branches that increase test failures)
- All tests pass, ruff clean

---

## Phase 37: Fix SSH backend missing shlex.quote in provision_workspace and release_workspace

**Goal:** `ssh.py:provision_workspace` (line 54) interpolates `base_branch`, `source_repo`, and `remote_path` into a shell command string without `shlex.quote()`, despite `spawn()` (line 83-84) already using `shlex.quote()` on its arguments. Similarly, `release_workspace` (line 161) uses `f"rm -rf {remote_path}"` without quoting. While these values currently come from config (user-authored) or UUID hex (safe), this is inconsistent with the security hardening applied across all other modules and violates defense-in-depth.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/backends/ssh.py:provision_workspace` (line 54): Apply `shlex.quote()` to `base_branch`, `source_repo`, and `remote_path` in the git clone command string
2. In `ssh.py:release_workspace` (line 161): Apply `shlex.quote()` to `remote_path` in the rm command
3. In `ssh.py:kill` (line 137): Apply `shlex.quote()` to the `handle.worker_id` in the pkill command (or validate it's safe)
4. Add test for `provision_workspace` verifying the command uses quoted arguments
5. Add test for `release_workspace` with a workspace path containing spaces
6. Verify all existing tests pass

### Verification

- All SSH shell command strings use `shlex.quote()` on interpolated values
- Consistent with quoting pattern already used in `spawn()`
- All tests pass, ruff clean

---

## Phase 38: Fix worker branch cleanup on success path and LocalBackend checkout -b retry failure

**Goal:** Two related workspace hygiene issues: (1) In `worker.py:_execute_unit`, the success path (lines 306-319) submits a merge request but never resets the workspace to the base branch or deletes the feature branch. Only the failure path (lines 328-332) does cleanup. Over many successful units, workspaces accumulate stale branches and remain checked out on old feature branches. (2) In `backends/local.py:provision_workspace` (line 45-52), `git checkout -b {branch_name}` is used without checking the return code. On unit retry, the branch already exists and the command fails silently, leaving the workspace on whatever branch it was on before. The worker then commits to the wrong branch.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/worker.py:_execute_unit` (after line 319, after `insert_merge_request`): Add workspace cleanup matching the failure path -- `checkout base_branch` and `branch -D branch_name`, with warning logs on failure
2. In `src/mission_control/backends/local.py:provision_workspace` (line 45): Switch `checkout -b` to `checkout -B` (force-create) so retried units overwrite the stale branch, OR delete the branch first if it exists. Also check the return code from the git command and raise on failure
3. Add test: execute two units on the same worker workspace, verify the workspace is on the base branch and has no stale branches after each completes
4. Add test: retry a failed unit (same unit.id) and verify `checkout -B` succeeds where `checkout -b` would fail
5. Verify all existing tests pass

### Verification

- Success path cleans up workspace (back on base branch, feature branch deleted)
- Unit retry creates branch successfully even if branch name already exists
- No stale branches accumulate over multiple successful units
- All tests pass, ruff clean

---

## Phase 39: Fix merge queue rebase target losing local merges

**Goal:** The merge queue merges branches into the local base branch but never pushes to origin. Subsequent MRs rebase onto `origin/{base}` via `_rebase_onto_base`, which does NOT include previously merged branches (only the remote state). This means the second MR in a batch effectively rebases onto the pre-first-merge state, potentially causing conflicts or silently losing the first merge's changes. The fix should rebase onto the local base branch ref instead of the remote tracking ref.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/merge_queue.py:_rebase_onto_base` (line 126): Change `rebase origin/{self.config.target.branch}` to `rebase {self.config.target.branch}` to use the local base branch (which includes prior merges) instead of the stale remote ref
2. The `git fetch origin` before rebase (line 124) can remain -- it updates the remote tracking ref for other purposes -- but the rebase target must be the local branch
3. Add test: merge two MRs in sequence, verify the second MR's rebase succeeds and the workspace contains both merges' changes
4. Add test: verify that after merging MR1, the rebase of MR2 uses the local base branch (not origin)
5. Verify all existing tests pass

### Verification

- Rebase uses local base branch ref, not `origin/{base}`
- Sequential merges preserve all previously merged changes
- All tests pass, ruff clean

---

## Phase 40: Remove duplicate WorkspacePool in Coordinator

**Goal:** `Coordinator.run()` creates both a `WorkspacePool` (line 104, stored as `self._pool`) and a `LocalBackend` (line 114) which internally creates its own `WorkspacePool`. Both pools manage clones in the same `pool_dir` with independent tracking (`_available`, `_in_use`). The Coordinator acquires the merge queue workspace from `self._pool`, but workers use `self._backend._pool`. The two pools have no coordination, potentially exceeding the intended clone limit and creating conflicting directory state.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Remove the standalone `WorkspacePool` creation at `coordinator.py:104-111`
2. Acquire the merge queue workspace from `self._backend` instead: use `await self._backend.provision_workspace("merge-queue", source_repo, self.config.target.branch)` or add a dedicated method to LocalBackend to expose a raw workspace
3. Update `self._backend` initialization to account for the merge queue clone in its `max_clones` count (currently `num_workers`, should be `num_workers + 1`)
4. Update cleanup logic to release through `self._backend` instead of `self._pool`
5. Add test: verify only one WorkspacePool is created during Coordinator initialization
6. Verify all existing tests pass

### Verification

- Only one WorkspacePool instance exists during Coordinator execution
- Merge queue workspace acquired through the same pool as worker workspaces
- Clone count limits are respected
- All tests pass, ruff clean

---

## Phase 41: Handle "blocked" unit status separately from failures

**Goal:** In `round_controller.py:_execute_single_unit`, when a unit reports `status: "blocked"` in its MC_RESULT, it falls through to the `else` branch (line 429-431) which sets `unit.status = "failed"` and increments `unit.attempt`. This penalizes blocked units the same as genuine failures, eventually exhausting retries for conditions beyond the unit's control (e.g., waiting for a dependency, needing human input). Blocked units should not increment the attempt counter.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py:_execute_single_unit` (around line 429): Add a check for `unit_status == "blocked"` before the failure path
2. When blocked: set `unit.status = "blocked"`, do NOT increment `unit.attempt`, log the blocking reason from `mc_result.get("summary")`
3. Ensure that blocked units can be retried (they should go back to pending status without penalizing the attempt counter)
4. Add test: unit with MC_RESULT status "blocked" should have attempt counter unchanged
5. Add test: blocked unit can be claimed again after being released
6. Verify all existing tests pass

### Verification

- Blocked units do not have attempt counter incremented
- Blocked units are marked with status "blocked" (not "failed")
- Blocked units can be retried without approaching max_attempts
- All tests pass, ruff clean

---

## Phase 42: Fix off-by-one in round limit (max_rounds executes N-1 rounds)

**Goal:** `RoundController` sets `mission.total_rounds = round_number` BEFORE calling `_should_stop`, which checks `total_rounds >= max_rounds`. This means the Nth round is never executed -- with `max_rounds = 20`, only 19 rounds run. The fix should check the condition after the round executes, or adjust the comparison.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py` (line 96): Move `mission.total_rounds = round_number` AFTER the round executes, or change the `_should_stop` check from `>=` to `>` so the current round is allowed to execute before stopping
2. Add test: with `max_rounds = 3`, verify exactly 3 rounds execute (not 2)
3. Verify all existing tests pass

### Verification

- With `max_rounds = N`, exactly N rounds execute
- All tests pass, ruff clean

---

## Phase 43: Fix SSH backend missing _stdout_collected.discard on worker reuse

**Goal:** `SSHBackend.spawn()` resets the stdout buffer but does NOT clear the `_stdout_collected` set entry for the worker_id. When a worker_id is reused (which happens when `WorkerAgent.run()` loops to claim another unit), `get_output` sees the worker_id in `_stdout_collected` and skips reading remaining stdout, returning empty string. The `LocalBackend` was fixed for this in Phase 33 but the same fix was never applied to `SSHBackend`.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/backends/ssh.py:spawn()` (after line 91): Add `self._stdout_collected.discard(worker_id)` to clear the collected flag when reusing a worker, matching the pattern in `LocalBackend.spawn()` line 72
2. Add test: spawn two units on the same worker_id on SSHBackend, verify both produce output via `get_output`
3. Verify all existing tests pass

### Verification

- SSHBackend workers produce output for all units, not just the first
- Matches LocalBackend behavior
- All tests pass, ruff clean

---

## Phase 44: Enforce DB asyncio.Lock for all concurrent access

**Goal:** The `Database.locked_call` method was added in Phase 30 to serialize concurrent DB access via asyncio.Lock, but it is never called anywhere in the codebase. All DB access in workers, coordinator, merge queue, and round controller goes through direct method calls (`db.claim_work_unit()`, `db.update_work_unit()`, etc.) without lock acquisition. Under concurrent load, interleaved `execute()` + `commit()` calls from different coroutines can corrupt transaction boundaries or cause `sqlite3.OperationalError`.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Identify all callers that access `db` from concurrent asyncio tasks: workers (heartbeat, claim, update), merge queue (get_next, update), coordinator (recover_stale, get_work_units, update_plan), round controller (update_work_unit)
2. Replace direct `db.method()` calls with `await db.locked_call("method", ...)` for all mutating operations called from concurrent contexts, OR refactor `locked_call` to be a decorator/wrapper that applies automatically
3. Consider making the lock more granular (per-table or per-operation) if contention is a concern
4. Add test: concurrent asyncio tasks performing DB operations do not raise OperationalError
5. Verify all existing tests pass

### Verification

- All concurrent DB access goes through the asyncio.Lock
- No `sqlite3.OperationalError` under concurrent load
- All tests pass, ruff clean

---

## Phase 45: Check worker checkout -b return value to prevent wrong-branch execution

**Goal:** `worker.py:_execute_unit` calls `git checkout -b {branch_name}` at line 229 but discards the return value. If the checkout fails (branch exists from incomplete cleanup), the worker continues executing Claude on whatever branch the workspace is currently on (likely the base branch or a stale feature branch). Commits go to the wrong branch, and the resulting merge request references a branch with wrong content.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/worker.py:_execute_unit` (line 229): Check the return value of `_run_git("checkout", "-b", ...)`. If False, attempt `checkout -B` (force-create) as a fallback. If that also fails, mark unit as failed and return early
2. Add test: simulate checkout -b failure, verify unit is marked failed with appropriate error message
3. Add test: simulate checkout -b failure then -B success, verify execution continues
4. Verify all existing tests pass

### Verification

- Worker does not execute Claude on wrong branch after checkout failure
- Graceful fallback to force-create branch
- All tests pass, ruff clean

---

## Phase 46: Add isinstance guards to handoff fields in RoundController

**Goal:** `round_controller.py:_execute_single_unit` passes `mc_result.get("discoveries", [])`, `mc_result.get("concerns", [])`, and `mc_result.get("files_changed", [])` directly to `json.dumps` without checking they're lists. If the LLM returns a string instead of a list, `json.dumps("string")` produces `'"string"'`. Later, `all_discoveries.extend(json.loads(h.discoveries))` iterates a string character-by-character, corrupting the discoveries list into individual characters. The `commits` field on line 407 already has the guard: `isinstance(commits, list)`.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py` (lines 409-411): Add `isinstance` guards matching the pattern on line 407, e.g. `json.dumps(mc_result.get("discoveries", []) if isinstance(mc_result.get("discoveries"), list) else [])`
2. Add test: MC_RESULT with string value for discoveries, verify handoff stores "[]" not the string
3. Add test: verify extend() on deserialized discoveries produces correct list (not character-split)
4. Verify all existing tests pass

### Verification

- Non-list handoff field values are converted to empty lists
- Consistent with commits field guard pattern
- All tests pass, ruff clean

---

## Phase 47: Fix merge queue rejection reset using origin/ instead of local branch

**Goal:** `merge_queue.py` line 96 resets the workspace to `origin/{branch}` after a rejected merge, but `origin/` may not include previously merged MRs (which were only merged locally). This is the same class of bug fixed in Phase 39 for the rebase target, but in the rejection cleanup path. After a rejection, the workspace loses all prior merged work, causing subsequent MR processing to fail or produce conflicts.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/merge_queue.py` (lines 95-96): Replace `reset --hard origin/{branch}` with just `checkout {branch}` (the local branch already has all prior merges). The reset was intended to clean up the workspace, but simply checking out the base branch is sufficient since it's already up-to-date with prior merges. If a hard reset is needed, use `reset --hard {branch}` (no `origin/` prefix)
2. Add test: after rejecting an MR, verify the workspace contains changes from a previously merged MR
3. Verify all existing tests pass

### Verification

- Rejection cleanup preserves prior merged work in the merge workspace
- Consistent with Phase 39 rebase target fix
- All tests pass, ruff clean

---

## Phase 51: Mark unit failed when merge to working branch fails in RoundController

**Goal:** In `round_controller.py` lines 423-431, when a unit completes with commits, `unit.status` is set to `"completed"` BEFORE the merge to the working branch is attempted. If `merge_to_working` fails (merge conflict), only a warning is logged -- the unit remains marked `"completed"` in the database even though its changes were never integrated. This causes the evaluator to score phantom progress, and the objective may never be met because the work was silently dropped.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py` (lines 423-431): Move `unit.status = "completed"` to AFTER the merge check. If `merged` is False, set `unit.status = "failed"`, increment `unit.attempt`, and set `unit.output_summary` to indicate merge conflict. This allows the unit to be retried on the next round
2. Add test: unit completes with commits but `merge_to_working` returns False -- verify `unit.status == "failed"` and `unit.attempt` is incremented
3. Add test: unit completes with commits and `merge_to_working` succeeds -- verify `unit.status == "completed"` (regression test)
4. Verify all existing tests pass

### Verification

- Failed merges cause the unit to be marked "failed" (not "completed")
- Unit attempt counter is incremented on merge failure, allowing retry
- Successful merges still mark unit as completed
- All tests pass, ruff clean, mypy clean

---

## Phase 52: Drain stdout during WorkerAgent polling loop to prevent pipe deadlock

**Goal:** `WorkerAgent._execute_unit` (lines 268-281) polls `check_status` in a loop but never reads stdout until after the process finishes (line 283). If the subprocess produces more than ~64KB of output (the OS pipe buffer size), it blocks on stdout writes. Since nobody is reading the pipe, `check_status` keeps returning "running" until the timeout is exceeded and the process is killed. All work is lost. This affects the Coordinator execution path (WorkerAgent) but not the mission mode path (RoundController uses `proc.communicate()` which handles this correctly).

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/worker.py` (inside the polling loop at lines 268-281): Call `await self.backend.get_output(handle)` on each iteration to drain the stdout pipe incrementally, discarding the return value (final output is collected after the loop)
2. Alternatively, refactor the polling loop to use `proc.communicate()` with a timeout, matching the pattern used in RoundController -- this eliminates the polling loop entirely and avoids the pipe buffer issue
3. Apply the same fix to `SSHBackend.get_output` which has the same issue (only reads when process is finished)
4. Add test: WorkerAgent with a subprocess that produces >64KB of output -- verify it completes instead of timing out
5. Verify all existing tests pass

### Verification

- Subprocess stdout is drained during execution, not only after completion
- Processes producing >64KB of output complete successfully
- SSH backend also drains output during execution
- All tests pass, ruff clean, mypy clean

---

## Phase 53: Prevent worker branch deletion before merge queue can fetch it

**Goal:** In `worker.py` lines 328-333, after a successful unit completion, the worker submits a `MergeRequest` then immediately deletes the feature branch and checks out the base branch. The merge queue (`merge_queue.py:_fetch_worker_branch`) later tries to fetch this branch from the worker's workspace by adding it as a git remote, but the branch was already deleted. The fetch fails and the MR is rejected with no work merged. This is a race condition between the worker's cleanup and the merge queue's asynchronous processing.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/worker.py` (lines 328-333): Remove the immediate branch deletion after MR submission. Instead, defer cleanup until the MR has been processed (merged or rejected). Options: (a) add an `await self._wait_for_mr_processed(mr.id)` method that polls the MR status before cleanup, (b) move branch cleanup responsibility to the merge queue (add cleanup after successful fetch), or (c) have the merge queue signal the worker to clean up via a status field
2. If option (b): In `merge_queue.py:_fetch_worker_branch`, after successfully creating the local branch from FETCH_HEAD, signal that the remote workspace branch can be cleaned up (e.g., by updating a status field on the MR or worker)
3. Add test: submit MR, verify the branch still exists in the worker workspace until after the merge queue has fetched it
4. Add test: verify the branch IS eventually cleaned up after the merge queue processes the MR
5. Verify all existing tests pass

### Verification

- Worker branch exists in workspace when merge queue tries to fetch it
- Branch cleanup happens after the merge queue has successfully fetched
- No stale branches accumulate indefinitely (cleanup still happens, just deferred)
- All tests pass, ruff clean, mypy clean

---

## Phase 57: Respect depends_on ordering in mission mode _execute_units

**Goal:** `round_controller.py:_execute_units` (lines 287-301) launches ALL work units concurrently via `asyncio.gather`, completely ignoring the `depends_on` field on `WorkUnit`. The recursive planner produces units with dependency relationships (e.g., "create API" must complete before "implement consumer"), but mission mode executes them all simultaneously. The Coordinator path correctly respects dependencies via `db.claim_work_unit` (SQL-level dependency check at db.py:607-631), but mission mode bypasses this entirely. Dependent units start on clones without prerequisite commits, causing failures and wasted compute.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py:_execute_units` (line 290): After fetching units, build a dependency DAG from `unit.depends_on` fields
2. Execute units in topological order: launch all units with no unmet dependencies first, wait for them to complete, then launch the next wave of unblocked units. Use the existing semaphore for concurrency within each wave
3. If a dependency fails, mark all transitive dependents as "blocked" (matching Phase 41's blocked status handling) without incrementing their attempt counters
4. Add test: create 3 units where B depends on A and C depends on B -- verify they execute in order A -> B -> C, not concurrently
5. Add test: when A fails, verify B and C are marked "blocked" (not "failed")
6. Verify all existing tests pass

### Verification

- Units with `depends_on` are not launched until their dependencies complete
- Dependency failures cascade as "blocked" status to downstream units
- Units without dependencies still run concurrently (no regression)
- All tests pass, ruff clean, mypy clean

---

## Phase 58: Check return values of delete_branch/merge_branch in scheduler

**Goal:** `scheduler.py` lines 92-96 call `delete_branch` and `merge_branch` which return `bool` indicating success/failure, but the return values are discarded. If `delete_branch` fails (e.g., branch doesn't exist, git in bad state), git may remain checked out on the session branch instead of `base_branch`. On the next loop iteration, `snapshot_project_health` runs verification on the wrong branch, corrupting the baseline. If `merge_branch` fails, the session's changes are silently lost -- the system records it as completed but the code is on an orphaned branch. Additionally, `spawn_session` at line 77 can raise `OSError`/`FileNotFoundError` if the `claude` binary is unavailable, crashing the entire scheduler loop (contrast with evaluator.py, planner.py, and green_branch.py which all catch this).

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/scheduler.py` (line 92-96): Capture the return value of `delete_branch`. If False, log an error and set `session.status = "revert_failed"`. Attempt manual recovery: `git checkout base_branch` to at least get back to the correct branch
2. Capture the return value of `merge_branch`. If False, log an error and set `session.status = "merge_failed"`. The session should NOT be recorded as completed work for discovery purposes
3. In `src/mission_control/scheduler.py` (around line 77): Wrap `spawn_session` in a try/except for `OSError` and `FileNotFoundError`, matching the pattern in `evaluator.py` (line 128-130). On failure, log error and continue to next iteration (or stop gracefully)
4. Add test: verify that a failed `delete_branch` sets session status to "revert_failed" and returns to base branch
5. Add test: verify that a failed `merge_branch` sets session status to "merge_failed"
6. Add test: verify that `OSError` from `spawn_session` is caught and scheduler continues
7. Verify all existing tests pass

### Verification

- Failed reverts/merges are logged and reflected in session status
- Scheduler remains on base branch even after failed git operations
- `OSError` from subprocess creation does not crash the scheduler loop
- All tests pass, ruff clean, mypy clean

---

## Phase 59: Check git return codes in WorkspacePool._reset_clone

**Goal:** `workspace.py:_reset_clone` (lines 109-135) runs three sequential git commands (`fetch origin`, `reset --hard origin/{base}`, `clean -fdx`) but ignores all return codes. If `git fetch origin` fails (network error, remote unreachable), `reset --hard origin/{base}` resets to a stale origin ref. If `reset --hard` fails (ref doesn't exist, corrupt repo), the clone retains dirty state from the previous worker. The next worker acquiring this clone inherits stale code or dirty state, causing wrong test results, commits on outdated code, or merge conflicts.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/workspace.py:_reset_clone` (lines 113-135): Check `returncode` after each git command. If `fetch` fails, log a warning and attempt a full re-clone (remove the clone directory and call `_create_clone`). If `reset --hard` fails, same fallback. If `clean -fdx` fails, log a warning (non-critical)
2. Add a return value (`bool`) to `_reset_clone` indicating success. Callers (`release` method at line 67) should handle failure by removing the clone from the pool rather than returning a dirty clone
3. Add test: simulate `git fetch origin` failure (mock returncode=1), verify the clone is re-created rather than returned dirty
4. Add test: simulate `git reset --hard` failure, verify fallback to re-clone
5. Verify all existing tests pass

### Verification

- Failed git commands in `_reset_clone` trigger re-clone fallback
- Dirty clones are never returned to the pool
- Network failures during reset are logged and handled gracefully
- All tests pass, ruff clean, mypy clean

## Phase 54: Drain stdout during RoundController polling loop to prevent pipe deadlock

**Goal:** `round_controller.py:_execute_single_unit` has the exact same pipe buffer deadlock bug that was fixed in `worker.py` (Phase 52). The polling loop (lines 377-381) calls `check_status` and sleeps but never calls `get_output` to drain stdout. If a Claude subprocess produces >64KB of output, it blocks on writes, causing the unit to time out and fail. This affects the mission mode execution path (RoundController) as opposed to the coordinator path (WorkerAgent).

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py` (inside the polling loop at lines 377-381): Add `await self._backend.get_output(handle)` before the `asyncio.sleep` call, matching the pattern used in `worker.py`
2. Verify all existing tests pass

### Verification

- Subprocess stdout is drained during execution in mission mode
- All tests pass, ruff clean, mypy clean

---

## Phase 55: Remove redundant 2>&1 shell redirect in state.py

**Goal:** `state.py` line 104 appends `" 2>&1"` to the verification command, but `_run_command` already sets `stderr=asyncio.subprocess.STDOUT` on line 78, which pipes stderr into stdout at the subprocess level. The shell-level redirect is redundant and confusing.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/state.py` (line 104): Remove `+ " 2>&1"` from the command string
2. Verify all existing tests pass

### Verification

- Verification output still captures both stdout and stderr
- All tests pass, ruff clean, mypy clean

---

## Phase 56: Rename shadowed timeout variable in RoundController execute loop

**Goal:** In `round_controller.py:_execute_single_unit`, line 374 creates a local `timeout` variable (the multiplied value) that shadows the concept of the effective timeout passed to `backend.spawn()`. When the unit times out (line 386), the error message reports the multiplied value, not the actual session timeout. This causes confusing debug output and makes it harder to diagnose timeout-related failures.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py` (line 374): Rename `timeout` to `poll_deadline_seconds` to distinguish from the effective_timeout used by the backend
2. Update the timeout error message on line 386 to use the new name
3. Verify all existing tests pass

### Verification

- Variable name clearly distinguishes backend timeout from polling deadline
- Error messages report accurate timeout values
- All tests pass, ruff clean, mypy clean

## Phase 60: Reset failed units to pending for retry in WorkerAgent

**Goal:** `worker.py:_execute_unit` marks failed units as `status="failed"` with `attempt += 1`, but never resets them to `"pending"` for retry. The coordinator's `_monitor_progress` correctly distinguishes permanently failed units (`attempt >= max_attempts`) from retriable ones, but since the worker never resets the status, units with retry budget remaining are permanently abandoned. In contrast, `merge_queue._release_unit_for_retry` correctly resets to `"pending"`. This means transient failures (network hiccups, timeouts) never get a second chance despite `max_attempts=3`.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/worker.py:_execute_unit` (the `else` branch at ~line 352): After setting `unit.status = "failed"` and incrementing `unit.attempt`, check if `unit.attempt < unit.max_attempts`. If so, reset `unit.status = "pending"`, `unit.claimed_at = None`, `unit.heartbeat_at = None`, `unit.started_at = None`, `unit.finished_at = None` so another worker can claim it
2. Keep the permanent failure path for `unit.attempt >= unit.max_attempts` -- these should stay `"failed"`
3. Apply same logic to all failure paths in `_execute_unit` (branch creation failure, backend error, timeout)
4. Add test: verify that a failed unit with `attempt < max_attempts` is reset to "pending"
5. Add test: verify that a failed unit with `attempt >= max_attempts` stays "failed"
6. Verify all existing tests pass

### Verification

- Failed units with remaining retries are reset to "pending" and can be reclaimed
- Permanently failed units (attempt >= max_attempts) stay "failed"
- All tests pass, ruff clean, mypy clean

---

## Phase 61: Initialize GreenBranchManager workspace for SSH backend in mission mode

**Goal:** `round_controller.py:_init_components` (lines 174-181) creates a `GreenBranchManager` but only initializes it with a workspace when the backend is `LocalBackend`. When using `SSHBackend`, the green branch manager's `workspace` attribute remains an empty string. All subsequent git operations (`merge_to_working`, `run_fixup`, `get_green_hash`) use `self.workspace` as `cwd` for subprocess calls. With `cwd=""`, git commands run in the process's current working directory instead of the target repo, causing silent data corruption or crashes. Mission mode is completely broken with SSH backend.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/round_controller.py:_init_components`: For SSH backend, provision a local workspace for the green branch manager using a local temporary clone of the target repo (the green branch merge/fixup flow requires local git operations regardless of where workers execute)
2. If creating a local workspace for SSH is too complex, raise an explicit `NotImplementedError` at startup if SSH backend is configured with mission mode, with a clear error message explaining that mission mode requires local workspace for merge/fixup operations
3. Add test: verify that `GreenBranchManager` is initialized with a valid workspace path for both Local and SSH backends (or that SSH raises the expected error)
4. Verify all existing tests pass

### Verification

- GreenBranchManager always has a valid workspace when used in mission mode
- SSH + mission mode either works or raises a clear error at startup
- All tests pass, ruff clean, mypy clean

---

## Phase 62: Standardize timeout clock source across polling loops

**Goal:** `round_controller.py:_execute_single_unit` uses `time.monotonic()` for its polling deadline, while `worker.py:_execute_unit` uses `asyncio.get_running_loop().time()`. Both are monotonic, but they can drift apart with non-default event loops (e.g., uvloop uses a different clock source). Standardizing prevents timing bugs if the event loop implementation changes.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. In `src/mission_control/worker.py:_execute_unit` (lines 286-291): Replace `asyncio.get_running_loop().time()` with `time.monotonic()` to match the round_controller pattern. Also import `time` if not already imported
2. Remove the `asyncio.get_running_loop()` calls for deadline computation
3. Verify all existing tests pass

### Verification

- Both polling loops use `time.monotonic()` consistently
- All tests pass, ruff clean, mypy clean
