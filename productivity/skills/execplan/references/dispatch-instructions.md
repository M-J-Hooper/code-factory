# ExecPlan Dispatch Instructions

Shared instructions for Execute and Resume mode dispatches. Include this content in the `<instructions>` block when dispatching the execution agent.

## Standard Instructions Block

```
<instructions>
- You are working at <worktree_path> on a dedicated branch. All work happens here.
- Update the Progress section in <plan_path> as you complete each step
- Record discoveries in Surprises & Discoveries
- Record decisions in Decision Log

PLAN CRITICAL REVIEW (before implementing):
- Re-read the entire plan with fresh eyes before writing any code
- Verify tasks are correctly ordered, dependencies are available, no obvious gaps
- If concerns exist, log them in Decision Log and resolve before proceeding
- If a concern is critical, stop and report

BATCH EXECUTION WITH FRESH SUBAGENT PER TASK AND TWO-STAGE REVIEW:
- Read the plan ONCE and extract ALL tasks with full text upfront
- Execute tasks in BATCHES of 3 (default). After each batch: update all living document sections, run tests, report progress, then proceed.
- For each task in the batch, dispatch a FRESH implementer subagent:
  - Inline the full task text + relevant context in the prompt (never make subagents read plan files)
  - Include scene-setting: milestone position, previously completed tasks summary, upcoming tasks, relevant discoveries, architectural context
  - The implementer asks questions before starting, self-reviews before reporting
- After each implementer completes, run TWO sequential reviews:
  1. Spec compliance review: fresh reviewer acknowledges strengths, then verifies nothing missing, nothing extra, nothing misunderstood. Includes severity assessment for orchestrator.
  2. Code quality review: fresh reviewer receives plan context (approach, architecture), reports strengths first, then assesses quality, architecture alignment, patterns (only after spec passes). Flags plan deviations as justified or problematic.
- If a reviewer finds issues: dispatch the implementer to fix → re-review → repeat until approved
- If code quality reviewer flags plan deviations: update plan and Decision Log if warranted
- STOP IMMEDIATELY on: missing dependencies, systemic test failures, unclear instructions, repeated verification failures, or discoveries that invalidate plan assumptions
- RE-PLAN TRIGGER: if a discovery reveals the plan needs fundamental changes, stop the batch, log with evidence, re-read the plan, and adjust before proceeding
- Never dispatch multiple implementers in parallel (causes conflicts)
- Never skip either review stage or proceed while issues remain open
- Never continue past a batch boundary without updating all living document sections

TDD ENFORCEMENT:
- For tasks that introduce or change behavior, follow TDD-first in exact order:
  1. Write failing test (complete code) → 2. Run and verify FAIL → 3. Implement minimal code → 4. Run and verify PASS → 5. Commit
  If you wrote code before its test, delete the implementation and restart with TDD. No exceptions.

COMMIT DISCIPLINE:
- Make atomic commits: each commit should contain one logical change
- Commit frequently using the /commit skill: Skill(skill="commit", args="<concise description>")
- Never use raw git commit or git checkout -b commands — always use the skills
- Do NOT commit the plan file itself — exclude .plans/ and *.plan.md when staging

- At completion, write the Outcomes & Retrospective section
</instructions>
```
