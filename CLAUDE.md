# CLAUDE.md

## Preferences

- Do what has been asked; nothing more, nothing less
- Never create files unless absolutely necessary; prefer editing existing files
- Never proactively create documentation or README files
- Always read the closest CLAUDE.md to the files you are investigating or changing
- If interrupted and redirected multiple times, save it as a memory

## Coding

- Follow the style of the existing code being changed
- Use `bzl` instead of `bazel` for all Bazel commands
- After modifying code, build and run tests: `bzl build` and `bzl test` from the repo root
- Prefer running single tests over the whole test suite

## Plans and State

All plan and state files live in `~/workspace/plans/` (outside any repo, never committed).

## Notes

- Sprint notes: `~/workspace/notes/<year>-<sprint>.md`
- New sprint: create a new file, copy over unfinished items from the previous one
- After creating a PR: add `[#PR-ID](URL) - TITLE` to the current sprint's note

## Skills

Available skills from the code-factory plugin marketplace. Use `/skill-name` or invoke via the Skill tool.

### Workflow

| Skill | Purpose |
|-------|---------|
| `/do` | Full feature lifecycle: refine → research → plan → execute → validate. Resumable, interactive or autonomous. |
| `/execplan` | Create, review, execute, or resume a standalone execution plan. |
| `/debug` | Structured debugging: investigate bugs, test failures, or unexpected behavior before fixing. |

### Git

| Skill | Purpose |
|-------|---------|
| `/commit` | Create a structured git commit from current changes. |
| `/atcommit` | Organize multi-file changes into atomic, dependency-safe commits. |
| `/branch` | Create a well-named feature branch from a ticket ID or description. |
| `/pr` | Push and create a GitHub pull request with a structured description. |
| `/pr-ready` | Fix CI failures and address automated review feedback on an open PR. |

### Code

| Skill | Purpose |
|-------|---------|
| `/review` | Review a pull request by number, URL, or branch name. |
| `/tour` | Guided walkthrough of a codebase, service, or code area. |

### Documentation and Meta

| Skill | Purpose |
|-------|---------|
| `/doc` | Create, update, improve, or audit Markdown documentation. |
| `/reflect` | Capture session learnings and update knowledge files. |
| `/workspace` | Bootstrap or update Claude Code configuration on a new machine. |
| `/skill-workbench` | Create, audit, or improve skills in the code-factory marketplace. |
