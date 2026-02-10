# Target: claude-orchestrator

## Location
- Path: `~/personal_projects/claude-orchestrator`
- Remote: `github.com:dannywillowliu-uchi/claude-orchestrator.git`
- Branch: `main`

## Description
Lightweight MCP server providing workflow tools for Claude Code. 13 tools covering workflow management, verification, and project memory.

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
uv run pytest -q && uv run ruff check src/ tests/ && uv run mypy src/claude_orchestrator --ignore-missing-imports
```

## Key Files
- `src/claude_orchestrator/server.py` -- MCP server and tool registration
- `src/claude_orchestrator/protocol.md` -- Workflow protocol (injected into CLAUDE.md)
- `src/claude_orchestrator/workflow.py` -- Workflow state management
- `src/claude_orchestrator/verification.py` -- Pre-commit verification gate
- `src/claude_orchestrator/project_memory.py` -- CLAUDE.md auto-updates
- `tests/test_e2e.py` -- End-to-end tests

## Constraints
- Tool count is currently 13 -- tests assert this; update test if adding/removing tools
- protocol.md is bundled as package data -- changes require reinstall or editable install
- Verification suite MUST pass before any commit (pytest, ruff, mypy, bandit)
- No breaking changes to existing MCP tool signatures without updating all consumers
