# Target: autonomous-dev-scheduler

## Location
- Path: `~/personal_projects/autonomous-dev-scheduler`
- Branch: `main`

## Description
Multi-agent mission-control system for autonomous development. Implements round controller, recursive planner, evaluator, green branch workflow, and pluggable backends.

## Tech Stack
- Python 3.11+
- Package manager: setuptools
- Testing: pytest + pytest-asyncio
- Linting: ruff
- Type checking: mypy
- Security: bandit

## Verification Command
```bash
.venv/bin/python -m pytest -q && .venv/bin/ruff check src/ tests/ && .venv/bin/python -m mypy src/mission_control --ignore-missing-imports
```

> **Note:** CLAUDE.md in the target project says `uv run` but that fails (`No such file or directory`). The `.venv/bin/python -m` approach is what actually works. Fix CLAUDE.md as part of Phase 8.

## Key Files
- `src/mission_control/round_controller.py` -- Round orchestration and execution loop
- `src/mission_control/recursive_planner.py` -- Recursive plan tree generation
- `src/mission_control/evaluator.py` -- Test evaluation and result analysis
- `src/mission_control/green_branch.py` -- Green branch workflow and fixup logic
- `src/mission_control/backends/` -- Pluggable backend implementations
- `src/mission_control/db.py` -- Database layer
- `src/mission_control/models.py` -- Data models
- `src/mission_control/config.py` -- Configuration management
- `src/mission_control/worker.py` -- Worker execution logic

## Constraints
- All tests must pass (293 tests)
- Virtual environment at `.venv/`
- asyncio_mode="auto" in pytest config
- Tabs for indentation
- 120 character line length
- Double quotes for strings
- Verification suite MUST pass before any commit (pytest, ruff, mypy, bandit)
