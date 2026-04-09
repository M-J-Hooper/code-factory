# Workflow and Planning

## Plan Before Code
- Explore -> Plan -> Implement -> Commit. No code before plan is complete.
- Ask clarifying questions for ambiguous requirements before coding.
- Draft and confirm approach before coding. List pros/cons when multiple approaches exist.

## Git
- Conventional commits: `<type>: <description>`. Types: feat, fix, refactor, docs, test, chore, perf, ci.
- Commit messages document intent (why), not mechanics (what).
- Keep diffs under 200 lines when possible. Small diffs, frequent commits.
- Never force-push to main. Never skip hooks (--no-verify).

## Context Management
- Use subagents for investigation to keep main context clean.
- /clear between unrelated tasks.

## Code Review
- Review order: Architecture > Correctness > Performance > Style.
