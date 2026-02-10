# Target: claude-orchestrator

## Location
- Path: `~/personal_projects/claude-orchestrator`
- Remote: `github.com:dannywillowliu-uchi/claude-orchestrator.git`
- Branch: `main`

## Description
Lightweight MCP server providing workflow tools for Claude Code. 15 tools covering workflow management, verification, self-correction, and project memory.

## Tech Stack
- Python 3.11+
- Package manager: uv
- Framework: FastMCP
- Testing: pytest
- Linting: ruff
- Type checking: mypy
- Security: bandit

## Verification Command
```bash
uv run pytest -q && uv run ruff check src/ tests/ eval/ && uv run mypy src/claude_orchestrator --ignore-missing-imports
```

## Key Files
- `src/claude_orchestrator/server.py` -- MCP server and tool registration
- `src/claude_orchestrator/protocol.md` -- Workflow protocol (injected into CLAUDE.md)
- `src/claude_orchestrator/workflow.py` -- Workflow state management
- `src/claude_orchestrator/fixer.py` -- Self-correcting verification analyzer
- `src/claude_orchestrator/plan_parser.py` -- Recursive sub-plan tree parser
- `src/claude_orchestrator/session_report.py` -- Structured Telegram message formatting
- `src/claude_orchestrator/review.py` -- Review artifact generation
- `src/claude_orchestrator/bootstrap.py` -- Project type detection and bootstrapping
- `src/claude_orchestrator/tool_groups.py` -- Phase-to-tool mapping
- `src/claude_orchestrator/project_memory.py` -- CLAUDE.md auto-updates
- `tests/test_e2e.py` -- End-to-end tests (103 tests)
- `eval/scenarios.py` -- Eval scenarios (37 across 10 dimensions)
- `eval/baseline.json` -- Eval baseline (100% pass rate)

## Constraints
- Tool count is currently 15 -- tests assert this; update test if adding/removing tools
- Eval baseline at eval/baseline.json -- re-run `python -m eval.runner --baseline` after changes
- protocol.md is bundled as package data -- changes require reinstall or editable install
- Verification suite MUST pass before any commit (pytest, ruff, mypy, bandit)
- No breaking changes to existing MCP tool signatures without updating all consumers
