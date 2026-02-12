# Session 027 - Discovery (Phases 32-34)

- **Date:** 2026-02-11
- **Target:** autonomous-dev-scheduler
- **Phases:** Discovery only
- **Outcome:** Completed

## Discovery

Ran `analyze_codebase_tool` (53 files, 9121 LOC, 1.01 test ratio) + deep Opus subagent audit (read all key source files). Found 26 issues total, verified top findings against source code. Discarded false positives (planner/evaluator zombie subprocess already fixed in session 026).

### Key Verified Findings

| Severity | Finding | File |
|----------|---------|------|
| Critical | Scheduler regression detection broken -- `previous == before` (self-comparison) | scheduler.py:59 |
| High | Cross-contaminated output parsing (pytest errors inflate mypy counts) | state.py:46-51 |
| High | `_parse_bandit` never called, security_findings always 0 | state.py:88-115 |
| High | `recover_stale_units` doesn't increment attempt counter (infinite retry) | db.py:602 |
| High | LocalBackend `_stdout_collected` not cleared on spawn (output loss) | local.py:65 |
| Medium | `_parse_pytest` errors not counted in test_failed | state.py:28-33 |
| Medium | Green branch `_run_claude` and `_run_command` no timeouts | green_branch.py:190-215 |
| Medium | Merge queue `_rebase_onto_base` leaves workspace on wrong branch | merge_queue.py:117-123 |

### False Positives Discarded

- Planner zombie subprocess (already has proc.kill since Phase 29)
- Evaluator zombie subprocess (already has proc.kill since Phase 29)

### New Phases Added

- Phase 32: Fix scheduler regression detection and test error counting (critical)
- Phase 33: Fix cross-contaminated output parsing, stale recovery attempt counter, LocalBackend output loss (high)
- Phase 34: Add timeouts to green_branch, fix rebase branch cleanup (medium)

All phases marked `checkpoint: true` per discovery constraints.
