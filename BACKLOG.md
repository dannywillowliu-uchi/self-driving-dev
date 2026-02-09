# Backlog

Target: `claude-orchestrator`

Each phase is a self-contained unit of work. Phases are executed in order unless dependencies say otherwise. Phases marked `checkpoint: true` pause for human review before the next session continues.

---

## Phase 1: Progressive Skill/Tool Disclosure

**Goal:** Reduce token overhead as MCP tools grow by only surfacing relevant tools per workflow phase.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Audit current tool registration in `server.py` -- catalog which tools are used in which workflow phases
2. Design a tool-group mapping: `{ "discovery": [...], "research": [...], "planning": [...], "execution": [...], "verification": [...] }`
3. Implement lazy tool registration or tool-group filtering so only phase-relevant tools appear in context
4. Update protocol.md to reference tool groups
5. Add tests verifying tool groups match expected tools per phase

### Verification

- All existing tests pass
- New tests for tool-group membership
- Token count comparison: measure prompt size before/after disclosure filtering

---

## Phase 2: Initializer Agent Pattern

**Goal:** Expand `init_project_workflow` into full environment bootstrapping -- detect project type, install dependencies, verify toolchain, configure verification suite.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Research Anthropic's initializer pattern: what setup steps are most valuable
2. Add project-type detection (Python/Node/Rust/Go) based on manifest files
3. Auto-configure verification commands per project type (pytest vs jest vs cargo test, etc.)
4. Generate a starter CLAUDE.md with project-specific verification if one doesn't exist
5. Add `--bootstrap` flag or separate `bootstrap_project` tool
6. Test with at least 2 project types (Python, Node)

### Verification

- Bootstrapping a fresh Python project produces correct config
- Bootstrapping a fresh Node project produces correct config
- Existing `init_project_workflow` behavior unchanged (backwards compatible)

---

## Phase 3: Evaluation Framework

**Goal:** Build a 20-50 task eval suite that measures phase success, not just test pass/fail. Enables measuring protocol improvements objectively.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** None

### Tasks

1. Define eval dimensions: task completion rate, verification pass rate, phase transition correctness, context recovery accuracy
2. Create 20 eval scenarios as structured test cases (input state + expected outcome)
3. Build eval runner that executes scenarios and scores results
4. Establish baseline scores with current protocol
5. Document how to add new eval scenarios

### Verification

- Eval runner executes all scenarios without errors
- Baseline scores recorded in `eval/baseline.json`
- At least 20 scenarios covering all workflow phases

---

## Phase 4: Review Queue for Checkpoints

**Goal:** Structured review artifacts at `checkpoint: true` phases. Instead of just "notify and stop", produce a reviewable summary.

**Status:** Not started
**Checkpoint:** false
**Dependencies:** None

### Tasks

1. Define review artifact format: changes summary, verification results, decisions made, risks identified
2. Add `generate_review_artifact` tool or integrate into `workflow_progress`
3. Store review artifacts in `.claude-project/reviews/phase-N.md`
4. Update protocol.md checkpoint guidance to reference review artifacts
5. Add Telegram integration: send review artifact summary with approve/reject buttons

### Verification

- Review artifact generated at checkpoint phases
- Artifact contains all required sections
- Telegram notification includes actionable summary

---

## Phase 5: Recursive Planner Architecture

**Goal:** Allow planning phase to produce sub-plan trees. A phase can itself contain sub-phases with their own verification criteria.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** Phase 4

### Tasks

1. Design sub-plan schema: how nested phases are represented in plan.md
2. Implement sub-plan parsing in workflow state reader
3. Update progress tracking to handle nested phase paths (e.g., "Phase 2 > Sub-phase 2.1")
4. Update auto-continue to navigate sub-plan trees depth-first
5. Add tests for nested plan execution and progress tracking

### Verification

- Nested plans parse correctly
- Progress tracks sub-phases accurately
- Auto-continue navigates depth-first through sub-plans

---

## Phase 6: Self-Correcting Agent Loops

**Goal:** "Fixer" agent role that monitors verification results and creates corrective tasks rather than blocking.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** Phase 3 (needs eval framework to measure improvement)

### Tasks

1. Design fixer agent behavior: when triggered, what it can fix, escalation rules
2. Implement fixer as a post-verification step: if non-critical issues found, create fix tasks
3. Fix tasks are appended to current phase or scheduled for next phase
4. Track fix success rate in eval framework
5. Add circuit breaker: if fixer creates > N tasks in one phase, escalate

### Verification

- Fixer creates appropriate tasks for non-critical issues
- Fixer does NOT attempt to fix critical issues (those still block)
- Circuit breaker triggers at threshold
- Eval framework shows improvement in task completion rate

---

## Phase 7: Async/Background Execution

**Goal:** Fire-and-forget workflows with Telegram milestones. Launch a session, walk away, get notified at checkpoints and completion.

**Status:** Not started
**Checkpoint:** true
**Dependencies:** Phase 4 (review queue), Phase 6 (self-correction)

### Tasks

1. Design background execution model: launchd/cron vs long-running process
2. Implement session launcher with background mode (`launcher.sh --background`)
3. Add structured Telegram reporting: phase start/complete, verification results, checkpoint reviews
4. Add session timeout and kill switch (max runtime per session)
5. Add session resume: if a background session dies, next launch picks up from progress.md
6. Test full background workflow: launch -> checkpoint notification -> resume -> completion

### Verification

- Background session runs to first checkpoint and notifies
- Session resume works after interruption
- Telegram messages contain structured, actionable information
- Kill switch terminates session cleanly
