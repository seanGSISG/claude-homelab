---
name: super-execute
description: Agent team execution engine that takes a validated implementation plan and drives execution with mandatory review gates at task, phase, and PR levels. Use when implementing multi-task plans that require strict quality gates and enforced review before completion.
---

# Super-Execute

## Purpose

Agent team execution engine that takes an implementation plan and drives it through mandatory review gates at every level — task, phase, and PR. Nothing ships without passing every gate.

**Announce at start:** "I'm using the super-execute skill to implement this plan with enforced review gates."

## When to Use

- You have a validated implementation plan (from `writing-plans` + `validating-plans`)
- You want mandatory code review after EVERY task
- You want phase-level compliance checking against the plan
- You want comprehensive PR review with forced fixes before merge

**Do NOT use for:**
- Plans with fewer than 3 tasks (use `subagent-driven-development` instead)
- Exploration or research (use `research-to-plan`)
- Writing the plan itself (use `writing-plans`)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SUPER-EXECUTE                        │
│                                                         │
│  Phase 0: Plan Validation ──── GATE: plan clean         │
│       │                                                 │
│       ▼                                                 │
│  ┌─────────────── Phase Loop ──────────────┐          │
│  │  ┌──────── Task Loop ──────────┐          │          │
│  │  │  Implement ──► Code Review  │          │          │
│  │  │       ▲            │        │          │          │
│  │  │       └── Fix ◄────┘        │          │          │
│  │  │            │                │          │          │
│  │  │       GATE: review clean    │          │          │
│  │  │            │                │          │          │
│  │  │         Commit              │          │          │
│  │  │            │                │          │          │
│  │  │       Next Task ────────────┘          │          │
│  │  └─────────────────────────────           │          │
│  │       │                                   │          │
│  │  Phase Compliance Check                   │          │
│  │       │                                   │          │
│  │  Phase Code Review                        │          │
│  │       │                                   │          │
│  │  GATE: phase clean ───► Next Phase ───────┘          │
│  └───────────────────────────────────────────           │
│       │                                                 │
│  Create PR + Push                                       │
│       │                                                 │
│  Comprehensive Review ◄──── (parallel: PR bots review)  │
│       │                                                 │
│  GATE: comprehensive clean                              │
│       │                                                 │
│  Address PR Bot Comments                                │
│       │                                                 │
│  GATE: all bot issues resolved                          │
│       │                                                 │
│  ✅ DONE                                                │
└─────────────────────────────────────────────────────────┘
```

## Required Skills

- `superpowers:requesting-code-review` — code review dispatch after each task
- `superpowers:finishing-a-development-branch` — branch completion
- `validating-plans` — pre-execution plan validation
- `comprehensive-review:full-review` — full review before merge
- `gh-address-comments` — address PR bot review comments

## Phase 0: Plan Validation

Before any code is written, validate the plan.

**Steps:**

1. Load the plan file
2. Invoke `validating-plans` skill to run full validation
3. If BLOCKERS or CRITICAL issues found:
   - Create TodoWrite tasks to fix the PLAN (not code)
   - Fix all plan issues
   - Re-run validation
   - Repeat until plan passes clean
4. GATE: Plan must have verdict ✅ PASS or ⚠️ PASS WITH NOTES

```
HARD GATE: Do NOT proceed to Phase 1 until plan validation passes.
```

**Output:** Validated plan file, ready for execution.

## Phase 1–N: Execution Phases

Group plan tasks into phases. Each phase is a logical batch of related tasks (typically 3-5 tasks per phase, following the plan's own grouping if it has one).

### Task Loop (within each phase)

For each task in the current phase:

#### Step 1: Dispatch Implementer

Dispatch a `general-purpose` subagent via Task tool:

```
Task tool:
  subagent_type: "general-purpose"
  description: "Implement task N"
  prompt: |
    You are implementing Task N of an implementation plan.
    
    PLAN CONTEXT:
    [Full plan text — do NOT make the agent read the file]
    
    YOUR TASK:
    [Full task text extracted from plan]
    
    COMPLETED SO FAR:
    [List of completed tasks and their commits]
    
    RULES:
    - Follow TDD: write failing test → run to verify fail → implement → run to verify pass
    - Follow the plan steps EXACTLY
    - Commit when tests pass
    - If blocked, ask questions — do NOT guess
    
    REQUIRED SUB-SKILL: Use superpowers:test-driven-development
```

#### Step 2: Code Review

After implementer completes, dispatch `superpowers:code-reviewer` subagent:

```
Task tool:
  subagent_type: "superpowers:code-reviewer"
  description: "Review task N implementation"
  prompt: |
    WHAT_WAS_IMPLEMENTED: [summary of what task N built]
    PLAN_OR_REQUIREMENTS: [full task text from plan]
    BASE_SHA: [SHA before task started]
    HEAD_SHA: [SHA after task committed]
    DESCRIPTION: [brief summary]
```

#### Step 3: Fix ALL Issues

**This is non-negotiable.**

- If reviewer returns Critical or Important issues:
  1. Dispatch a `general-purpose` fix subagent with the exact issues
  2. Fix subagent addresses EVERY issue (not "most" — ALL)
  3. Fix subagent commits fixes
  4. Re-dispatch code reviewer on the fix commit
  5. Repeat until reviewer returns clean (no Critical or Important issues)

```
HARD GATE: Do NOT proceed to next task until code review is clean.
Clean = zero Critical issues, zero Important issues.
Minor/Nit issues are noted but do not block.
```

#### Step 4: Commit Checkpoint

After clean review:
1. Ensure all changes are committed
2. Update TodoWrite — mark task complete
3. Record the commit SHA for phase tracking

#### Step 5: Next Task

Move to next task in the phase. Repeat Steps 1-4.

### Phase Gate (after all tasks in phase complete)

After every task in the phase has passed its individual review:

#### Phase Compliance Check

Dispatch a compliance checking subagent:

```
Task tool:
  subagent_type: "general-purpose"
  description: "Phase N compliance check"
  prompt: |
    You are a compliance auditor. Your job is to verify that the implementation
    strictly adheres to the plan.
    
    IMPLEMENTATION PLAN:
    [Full plan text]
    
    PHASE BEING CHECKED: Phase N
    [Phase task list with descriptions]
    
    COMMITS IN THIS PHASE:
    [List of all commit SHAs and messages from this phase]
    
    YOUR JOB:
    1. git diff the full phase (BASE_SHA..HEAD_SHA)
    2. Compare EVERY requirement in the phase tasks against the actual code
    3. Flag any:
       - Missing requirements (plan says X, code doesn't have X)
       - Extra code not in plan (scope creep)
       - Deviations from specified approach
       - Test gaps (plan specifies tests that weren't written)
    
    OUTPUT FORMAT:
    - COMPLIANT: [list of requirements met]
    - NON-COMPLIANT: [list of gaps with specific details]
    - SCOPE CREEP: [list of additions not in plan]
    - VERDICT: ✅ COMPLIANT | ⚠️ MINOR DEVIATIONS | 🔴 NON-COMPLIANT
    
    If NON-COMPLIANT, explain exactly what needs to change.
    If deviations exist, they MUST have clear technical justification.
```

#### Phase Code Review

Dispatch `superpowers:code-reviewer` for the ENTIRE phase:

```
Task tool:
  subagent_type: "superpowers:code-reviewer"
  description: "Review phase N as a whole"
  prompt: |
    WHAT_WAS_IMPLEMENTED: [summary of all tasks in phase N]
    PLAN_OR_REQUIREMENTS: [full phase text from plan]
    BASE_SHA: [SHA before phase started]
    HEAD_SHA: [SHA after phase completed]
    DESCRIPTION: Phase N complete review - checking cross-task integration
```

#### Fix Phase Issues

If compliance check or phase review surfaces issues:
1. Dispatch fix subagent for each set of issues
2. Fix ALL issues (compliance gaps AND review findings)
3. Re-run BOTH compliance check and phase review
4. Repeat until both are clean

```
HARD GATE: Do NOT proceed to next phase until:
  - Compliance verdict is ✅ COMPLIANT or ⚠️ MINOR DEVIATIONS (with justification)
  - Phase code review has zero Critical/Important issues
```

**Then and only then: proceed to next phase.**

## Post-Execution: PR Pipeline

After ALL phases complete and pass their gates:

### Step 1: Create PR + Push

1. Invoke `superpowers:finishing-a-development-branch` skill
2. Create the PR with a comprehensive description summarizing:
   - What was built (per phase)
   - All compliance check results
   - All review results
   - Commit history

### Step 2: Comprehensive Review (while PR bots work)

Immediately after pushing:

1. Invoke `comprehensive-review:full-review` skill
2. This runs in parallel with external PR review bots (CodeRabbit, etc.)
3. Fix ALL issues surfaced by comprehensive review:
   - Dispatch fix subagents for each finding
   - Re-run comprehensive review to verify fixes
   - Repeat until clean
4. Commit and push fixes

```
HARD GATE: ALL comprehensive review findings must be resolved.
```

### Step 3: Address PR Bot Comments

After comprehensive review is clean AND PR bots have finished:

1. Invoke `gh-address-comments` skill
2. This reads all PR bot comments (CodeRabbit, etc.)
3. Fix ALL issues surfaced by PR bots:
   - Address every comment
   - Dispatch fix subagents as needed
   - Push fixes
4. Repeat until all bot comments are resolved

```
HARD GATE: ALL PR bot comments must be addressed.
Zero unresolved comments before declaring done.
```

### Step 4: Done

Only after ALL of these pass:
- ✅ Every task reviewed and clean
- ✅ Every phase compliant and reviewed
- ✅ Comprehensive review clean
- ✅ All PR bot comments addressed

**Then and only then is the work complete.**

## Gate Summary

| Gate | Trigger | Blocks | Clean Means |
|------|---------|--------|-------------|
| Plan Validation | Before any code | Phase 1 start | No blockers or criticals in plan |
| Task Review | After each task commit | Next task | Zero Critical/Important review issues |
| Phase Compliance | After all phase tasks | Next phase | Plan adherence verified |
| Phase Review | After compliance passes | Next phase | Zero Critical/Important across phase |
| Comprehensive Review | After PR created | Bot comment addressing | All findings resolved |
| PR Bot Comments | After bots finish | Completion | All comments addressed |

## Agent Roles

| Agent | Type | Dispatched When | Job |
|-------|------|----------------|-----|
| Implementer | `general-purpose` | Each task | Write code following plan + TDD |
| Code Reviewer | `superpowers:code-reviewer` | After each task, after each phase | Find issues in implementation |
| Fix Agent | `general-purpose` | When review finds issues | Fix specific issues from review |
| Compliance Checker | `general-purpose` | After each phase | Verify plan adherence |
| Comprehensive Reviewer | `comprehensive-review:full-review` | After PR created | Deep multi-dimensional review |
| PR Comment Handler | `gh-address-comments` | After bots finish | Address external review feedback |

## TodoWrite Integration

Create todos that mirror the execution structure:

```
Phase 0: Validate plan
  └─ Fix plan issues (if any)

Phase 1: [Phase Name]
  ├─ Task 1: [name] → implement → review → fix
  ├─ Task 2: [name] → implement → review → fix
  ├─ Task 3: [name] → implement → review → fix
  ├─ Phase 1 compliance check
  └─ Phase 1 code review → fix

Phase 2: [Phase Name]
  ├─ Task 4: [name] → implement → review → fix
  ├─ ...
  ├─ Phase 2 compliance check
  └─ Phase 2 code review → fix

Post-execution:
  ├─ Create PR + push
  ├─ Run comprehensive review → fix all
  ├─ Address PR bot comments → fix all
  └─ Verify complete
```

Mark each todo as `in_progress` when starting, `completed` when done. Only one `in_progress` at a time.

## Red Flags

**Never:**
- Skip a review gate ("it's a small change")
- Proceed with unresolved Critical/Important issues
- Let an implementer also be its own reviewer
- Skip compliance check ("the task reviews were clean")
- Skip comprehensive review ("all phases passed")
- Skip PR bot comments ("comprehensive review caught everything")
- Declare done with unresolved issues at ANY level
- Start on main/master without explicit user consent
- Parallelize implementation agents (conflicts)

**If blocked:**
- Stop and surface the blocker
- Do NOT guess or work around
- Ask the user for guidance

**If a fix introduces new issues:**
- The fix goes through review too
- No exception — review loops until clean

## Example Flow

```
You: I'm using the super-execute skill to implement this plan with enforced review gates.

── Phase 0: Plan Validation ──
[Invoke validating-plans]
Result: ⚠️ PASS WITH NOTES (2 warnings, non-blocking)
GATE PASSED ✅

── Phase 1: Core Data Models (Tasks 1-3) ──

Task 1: User model
  [Dispatch implementer] → implements + tests + commits
  [Dispatch code reviewer] → 1 Important issue: missing index
  [Dispatch fix agent] → adds index, commits
  [Re-dispatch code reviewer] → clean ✅
  Task 1 GATE PASSED ✅

Task 2: Auth service  
  [Dispatch implementer] → implements + tests + commits
  [Dispatch code reviewer] → clean ✅
  Task 2 GATE PASSED ✅

Task 3: Session handler
  [Dispatch implementer] → implements + tests + commits
  [Dispatch code reviewer] → 2 Critical issues
  [Dispatch fix agent] → fixes both, commits
  [Re-dispatch code reviewer] → 1 Important remaining
  [Dispatch fix agent] → fixes it, commits
  [Re-dispatch code reviewer] → clean ✅
  Task 3 GATE PASSED ✅

Phase 1 Compliance Check:
  [Dispatch compliance agent]
  Result: ✅ COMPLIANT — all 3 task requirements met
  
Phase 1 Code Review:
  [Dispatch code reviewer for full phase diff]
  Result: 1 Important — inconsistent error handling across models
  [Dispatch fix agent] → standardizes error handling, commits
  [Re-dispatch phase reviewer] → clean ✅
  Phase 1 GATE PASSED ✅

── Phase 2: API Endpoints (Tasks 4-6) ──
  [... same pattern ...]
  Phase 2 GATE PASSED ✅

── Post-Execution ──

[Create PR + push]
[Invoke comprehensive-review:full-review]
  Found: 3 issues (1 security, 2 performance)
  [Fix all 3, push]
  [Re-run comprehensive review] → clean ✅
  COMPREHENSIVE GATE PASSED ✅

[PR bots finished — CodeRabbit left 5 comments]
[Invoke gh-address-comments]
  [Address all 5 comments, push]
  PR BOT GATE PASSED ✅

✅ SUPER-EXECUTE COMPLETE
  - 6 tasks implemented and reviewed
  - 2 phases compliance-checked
  - Comprehensive review clean
  - All PR bot comments addressed
  - Ready to merge
```

## Integration

**Upstream (creates the plan this skill executes):**
- `superpowers:brainstorming` → `superpowers:writing-plans` → `validating-plans`

**Or use `research-to-plan` which combines brainstorming + writing + validation.**

**Downstream (finishing up):**
- `superpowers:finishing-a-development-branch` — branch completion + PR creation
- `comprehensive-review:full-review` — deep review post-PR
- `gh-address-comments` — address PR bot feedback

**During execution:**
- `superpowers:test-driven-development` — implementer agents follow TDD
- `superpowers:requesting-code-review` — code review dispatch pattern
- `superpowers:systematic-debugging` — if implementer hits unexpected failures
