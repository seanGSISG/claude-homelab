# Validating Plans Skill

Systematic plan validation before execution using specialized validator agents.

## What It Does

- Validates implementation plans before code execution
- Coordinates three parallel validator agents:
  - **Static Validator** - Checks plan completeness and logic
  - **Environment Validator** - Verifies dependencies and configuration
  - **Architecture Validator** - Ensures design alignment
- Creates TodoWrite tasks for any issues found
- Integrates with superpowers workflow (`writing-plans` → `validating-plans` → `executing-plans`)
- Gates execution until all validation issues are resolved

All operations are automated - no manual intervention required once invoked.

## Setup

### No Configuration Required

This skill uses Claude's built-in Task tool for agent coordination. No credentials, API keys, or external services needed.

### Prerequisites

- Works as part of the superpowers workflow
- Requires a plan file (created by `writing-plans` skill)
- Expects plan at standard location (specified during validation)

## Usage Examples

### Basic Validation

After creating a plan with the `writing-plans` skill:

```
User: "Validate my plan before executing it"

Claude: Invokes /validate-plan command
- Spawns 3 parallel validator agents
- Each agent reviews the plan from their perspective
- Issues are collected and added to TodoWrite
- Reports validation results
```

### Integrated Workflow

As part of the full superpowers cycle:

```
1. writing-plans → Creates PLANS.md
2. validating-plans → Validates PLANS.md (this skill)
3. executing-plans → Implements the validated plan
```

### Validation Output

The skill produces:
- **TodoWrite tasks** for each validation issue (you fix PLANS, not code)
- **Validation summary** with pass/fail status
- **Detailed findings** from each validator agent
- **Recommended fixes** for any issues found

## How It Works

### Validation Process

1. **Plan Ingestion** - Reads the plan file from disk
2. **Parallel Validation** - Spawns 3 agent validators simultaneously:
   - Static Validator checks plan structure and completeness
   - Environment Validator verifies dependencies and setup
   - Architecture Validator ensures design principles
3. **Issue Collection** - Gathers findings from all validators
4. **Task Creation** - Creates TodoWrite tasks for issues
5. **Gate Decision** - Determines if plan is ready for execution

### Validation Criteria

**Static Validation:**
- All steps are clearly defined
- No ambiguous instructions
- Logical step ordering
- Clear acceptance criteria

**Environment Validation:**
- Required dependencies documented
- Configuration files specified
- Environment variables defined
- No missing prerequisites

**Architecture Validation:**
- Follows established patterns
- Respects separation of concerns
- Maintains backward compatibility
- Scalable and maintainable design

## Workflow

When to use this skill:

1. **After creating a plan** with `writing-plans` skill
2. **Before executing a plan** with `executing-plans` skill
3. **When plan quality is uncertain**
4. **As part of automated superpowers workflow**

### Decision Tree

```
User creates plan
    ↓
Invoke /validate-plan
    ↓
3 validators run in parallel
    ↓
Issues found?
    ├─ YES → TodoWrite tasks created → Fix plan → Re-validate
    └─ NO → Plan approved → Ready for execution
```

## Integration with Superpowers

This skill is part of the superpowers workflow ecosystem:

- **Input:** Plan file (from `writing-plans` skill)
- **Output:** Validation report + TodoWrite tasks
- **Next Step:** `executing-plans` skill (only if validation passes)

### GitHub Issue Workflow

After validation, optionally:
1. Post validation report as GitHub issue comment
2. Tag issue with validation status
3. Block PR merge if validation fails

See `references/github-issue-workflow.md` for details.

## Troubleshooting

### "Plan file not found"

Ensure:
- Plan was created with `writing-plans` skill
- Plan file path is correct
- File hasn't been moved or deleted

### Validation fails repeatedly

Check:
- Are you fixing the PLAN (not the code)?
- Are all validator recommendations addressed?
- Is the plan detailed enough?

### Validators timeout

- Plan may be too large or complex
- Try breaking into smaller plans
- Check network connectivity for agent communication

## Notes

- Validators run in parallel for speed
- TodoWrite tasks target the PLAN file, not code
- Validation is non-destructive (read-only on plan)
- Can be run multiple times (idempotent)
- Part of quality gates before execution
- Designed for automation in CI/CD pipelines

## Reference

- `references/agent-guide.md` - Validator agent specifications
- `references/github-issue-workflow.md` - GitHub integration
- Superpowers workflow documentation
- TodoWrite task system

---

**Version:** 1.0.0
**Type:** Read-Only + Task Creation
**Dependencies:** Claude Task tool, TodoWrite system
