# ExecPlan Author Instructions

Include this content in the `<instructions>` block when dispatching the author agent.

## Standard Instructions Block

```
<instructions>
- Before writing the plan, research thoroughly using both local source code and Confluence:
  1. Local codebase: use Glob, Grep, and Read to explore relevant files, modules, patterns, and conventions in the repo. Understand the existing architecture, types, and interfaces that the plan will interact with.
  2. Confluence: use the Atlassian MCP tools (searchConfluenceUsingCql, getConfluencePage) to search for related design docs, RFCs, ADRs, runbooks, and team knowledge. Search using key terms from the task description. Incorporate relevant findings into the plan's Context and Orientation section.
- Embed all research findings directly into the plan — do not reference external links without summarizing the relevant content inline.
- Create the .plans/ directory if it does not exist
- Write the ExecPlan to the output path above
- Follow the ExecPlan format from your agent instructions to the letter
- The plan must be fully self-contained, written for a complete novice
- Honor the chosen approach from <chosen_approach> — do not revisit rejected alternatives or introduce a new strategy without flagging the deviation in the Decision Log
- YAGNI: only plan what was requested — do not add features, abstractions, or capabilities beyond the task description

TASK GRANULARITY AND TDD-FIRST STRUCTURE:
- Break work into bite-sized steps — each step is one action (write test, run test, implement, run test, commit)
- For tasks introducing new behavior, TDD-first structure is MANDATORY: write failing test → verify failure → implement minimal code → verify passing → commit
- NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST — this is non-negotiable for behavior-changing tasks
- Include complete test code in the plan (not "add a test for X")
- Include exact commands with expected output AND expected failure messages (not "run the tests")
- Include complete code for new function signatures and interface definitions
- Include a rationalization table for TDD exemptions: config-only, docs, and behavior-preserving refactors are exempt; everything else must follow TDD

- Include all mandatory sections: Purpose/Big Picture, Progress, Surprises & Discoveries,
  Decision Log, Outcomes & Retrospective, Context and Orientation, Plan of Work,
  Concrete Steps, Validation and Acceptance, Idempotence and Recovery, Artifacts and Notes,
  Interfaces and Dependencies
- Do NOT commit the plan file — ExecPlan files are working documents that live in the repo but are never committed
</instructions>
```
