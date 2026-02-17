---
name: execplan
description: >
  Use when the user wants to create, execute, review, or resume an ExecPlan.
  Triggers: "create a plan", "run this plan", "resume the plan",
  "review the plan", "write a plan for X", or references to .plan.md files.
argument-hint: "[task description or path to existing plan]"
user-invocable: true
---

# ExecPlan

Announce: "I'm using the execplan skill to manage execution plans."

## Step 1: Discover Existing Plans

Ensure `.plans/` is gitignored:

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
if ! grep -q "^\.plans/$" "$REPO_ROOT/.gitignore" 2>/dev/null; then
  echo ".plans/" >> "$REPO_ROOT/.gitignore"
fi
```

Search the project for existing ExecPlan files:

- Glob for `.plans/*.plan.md`
- Glob for `**/*.plan.md` (max depth 3, excluding `.plans/`)
- Check for `EXECPLAN.md` or `PLAN.md` in project root

For each discovered plan, read its Progress section and classify:

| Pattern | Status |
|---------|--------|
| No Progress section or no checked items | `not-started` |
| Has both `- [x]` and `- [ ]` items | `in-progress` |
| All items are `- [x]` | `completed` |

Store the list of discovered plans with their paths and statuses.

## Step 2: Mode Selection

Determine mode from `$ARGUMENTS` and discovered plans.

**IMPORTANT: Never skip Author Mode.** When the arguments are a task description, you MUST dispatch the Author Mode subagent to write a plan. Do not implement the task directly, regardless of how simple it appears. The entire point of `/execplan` is to produce a plan first.

**Classification rules — apply in this order:**

1. **Review request** — `$ARGUMENTS` contains the word "review":
   - If a plan path is also provided, use **review** mode for that plan.
   - If no plan path is provided but `not-started` plans exist, ask which plan to review.
   - If no plans exist, inform the user they need to author a plan first.

2. **File path** — `$ARGUMENTS` is a local file path (contains `/` or ends in `.md`) AND does NOT start with `http://` or `https://`:
   - Verify the file exists. If not, report error and list any discovered plans.
   - Classify the plan:
     - `not-started` -> ask user whether to **review** or **execute**
     - `in-progress` -> **resume** mode
     - `completed` -> inform user; offer to author a new plan

3. **Task description** — anything else (including arguments containing URLs):
   - Use **author** mode with the provided description.

**If no arguments and existing plans were found:**

```
AskUserQuestion(
  header: "ExecPlan",
  question: "I found existing execution plans. What would you like to do?",
  options: [
    "Author new plan" -- Create a new ExecPlan from scratch,
    "<plan-name> (status)" -- one option per discovered plan
  ]
)
```

If the user selects a `not-started` plan:

```
AskUserQuestion(
  header: "ExecPlan",
  question: "What would you like to do with this plan?",
  options: [
    "Review" -- Walk through the plan, ask clarifying questions, and refine it before executing,
    "Execute" -- Execute the plan as-is
  ]
)
```

**If no arguments and no plans found:**

```
AskUserQuestion(
  header: "ExecPlan",
  question: "No existing plans found. What would you like to create an execution plan for?",
  options: [] // free-text response expected
)
```

Use their response as the task description for author mode.

## Step 3: Dispatch

### Author Mode

If the task description is fewer than 10 words, ask for more detail before dispatching.

Generate a slug from the task description: lowercase, hyphens, max 50 chars.

Dispatch:

```
Task(
  subagent_type = "productivity:execplan",
  description = "Author ExecPlan: <short description>",
  prompt = "
Author a new ExecPlan for the following task.

<task>
<the user's task description>
</task>

<output_path>
.plans/<slug>.plan.md
</output_path>

<instructions>
- Before writing the plan, research thoroughly using both local source code and Confluence:
  1. Local codebase: use Glob, Grep, and Read to explore relevant files, modules, patterns, and conventions in the repo. Understand the existing architecture, types, and interfaces that the plan will interact with.
  2. Confluence: use the Atlassian MCP tools (searchConfluenceUsingCql, getConfluencePage) to search for related design docs, RFCs, ADRs, runbooks, and team knowledge. Search using key terms from the task description. Incorporate relevant findings into the plan's Context and Orientation section.
- Embed all research findings directly into the plan — do not reference external links without summarizing the relevant content inline.
- Create the .plans/ directory if it does not exist
- Write the ExecPlan to the output path above
- Follow the ExecPlan format from your agent instructions to the letter
- The plan must be fully self-contained, written for a complete novice

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
"
)
```

After the agent returns, report:
```
ExecPlan authored: .plans/<slug>.plan.md

To review: /execplan review .plans/<slug>.plan.md
To execute: /execplan .plans/<slug>.plan.md
```

### Review Mode

Review mode is an interactive walkthrough of the plan with the user. It happens in the main conversation (not in a subagent) so the user can participate directly.

Read the plan file content:

```
PLAN_CONTENT = Read("<plan_path>")
```

**Walkthrough procedure:**

Walk through the plan one section at a time, in order. For each section:

1. **Summarize** the section in 2-3 plain-language sentences, highlighting the key decisions and assumptions the plan makes.
2. **Flag** anything that looks ambiguous, risky, or worth confirming — e.g., technology choices, file paths that might not exist, assumptions about the codebase, missing edge cases, or steps that seem underspecified.
3. **Ask** the user a clarification question using `AskUserQuestion` if there is anything flagged. If the section looks solid and unambiguous, say so and move on without asking.

The sections to walk through, in order:

1. **Purpose / Big Picture** — Does the stated goal match what the user actually wants? Is the scope right?
2. **Context and Orientation** — Are the referenced files, modules, and terms accurate? Anything missing?
3. **Plan of Work** — Is the sequence of changes logical? Are there missing steps or unnecessary ones?
4. **Concrete Steps** — Are the commands and paths correct? Do they match the project's actual toolchain?
5. **Milestones** (if present) — Is the breakdown reasonable? Are milestones independently verifiable as claimed?
6. **Validation and Acceptance** — Are the acceptance criteria specific enough? Would you know success from failure?
7. **Idempotence and Recovery** — Are there risky steps that need better rollback paths?
8. **Interfaces and Dependencies** — Are the specified types, libraries, and APIs correct?

Skip sections that are empty or not yet populated (like Progress, Decision Log, etc. — these are living sections filled during execution).

After walking through all sections, present a summary:

```
AskUserQuestion(
  header: "Review complete",
  question: "I've reviewed the plan. Here's a summary of what we discussed:\n\n<bullet list of changes agreed upon, if any>\n\nHow would you like to proceed?",
  options: [
    "Update and execute" -- Apply the agreed changes to the plan, then execute it,
    "Update only" -- Apply the agreed changes but don't execute yet,
    "Execute as-is" -- Execute the plan without changes,
    "Cancel" -- Do nothing for now
  ]
)
```

**If the user chose "Update and execute" or "Update only":**

Dispatch a subagent to apply the revisions:

```
Task(
  subagent_type = "productivity:execplan",
  description = "Revise ExecPlan: <plan filename>",
  prompt = "
Revise the following ExecPlan based on review feedback from the user.

<plan_path>
<the plan file path>
</plan_path>

<plan>
<the full plan content>
</plan>

<revisions>
<numbered list of specific changes to make, gathered from the review conversation>
</revisions>

<instructions>
- Read the current plan from <plan_path>
- Apply each revision precisely
- Maintain all mandatory ExecPlan sections
- Keep the plan self-contained — do not introduce references to this review conversation
- Record each revision in the Decision Log with rationale: 'Review feedback from user'
- Add a note at the bottom of the plan describing the revision pass
- Write the updated plan back to <plan_path>
- Do NOT commit the plan file
</instructions>
"
)
```

After the revise agent returns:
- If the user chose "Update and execute", proceed to **Execute Mode** with the updated plan.
- If the user chose "Update only", report:
  ```
  ExecPlan updated: <plan_path>

  To execute: /execplan <plan_path>
  ```

**If the user chose "Execute as-is":**

Proceed directly to **Execute Mode**.

**If the user chose "Cancel":**

Report that no changes were made and the plan is available at `<plan_path>`.

**If the user provided custom feedback (selected "Other" or gave a free-text response instead of one of the four options above):**

The user has additional feedback that was not covered during the section-by-section walkthrough. Handle it as follows:

1. Collect the user's feedback as additional revision items.
2. Dispatch the revision subagent (same as the "Update and execute" flow above) to apply the changes to the plan.
3. After the revision agent returns, **re-present the "Review complete" summary** with the same four options. Include the user's latest feedback in the bullet list of changes.

This creates a loop: the user can keep giving feedback until they select one of the four predefined options. Do NOT proceed to execution on custom feedback — always re-ask.

### Execute Mode

#### Step 1: Set Up Workspace

Extract a short description from the plan filename or task description for naming.

Ask the user how they want to work:

```
AskUserQuestion(
  header: "Workspace",
  question: "Where should this plan be executed?",
  options: [
    "Worktree + new branch (Recommended)" -- Create an isolated git worktree and feature branch so main workspace stays clean,
    "New branch in current directory" -- Create a feature branch here without a worktree,
    "Current branch" -- Work on the already checked-out branch with no worktree or branch creation
  ]
)
```

**If the user chose "Worktree + new branch":**

1. Invoke the `/worktree` skill to create an isolated workspace:

```
Skill(skill="worktree", args="<short description from plan>")
```

The skill will report the worktree path. Store it as `WORKTREE_PATH`.

2. Change into the worktree directory:

```
cd <WORKTREE_PATH>
```

3. Invoke the `/branch` skill to create a feature branch:

```
Skill(skill="branch", args="<short description from plan>")
```

4. Copy the plan file into the worktree so the execution agent can update it:

```
cp <original plan_path> <WORKTREE_PATH>/<plan_path>
```

**If the user chose "New branch in current directory":**

1. Store the current working directory as `WORKTREE_PATH`.

2. Invoke the `/branch` skill to create a feature branch:

```
Skill(skill="branch", args="<short description from plan>")
```

No plan file copy is needed — the plan is already accessible.

**If the user chose "Current branch":**

1. Store the current working directory as `WORKTREE_PATH`.

No branch creation or plan file copy needed — work proceeds on the current branch.

#### Step 2: Dispatch Execution Agent

Read the plan file content (it must be inlined — `@` references don't work across Task boundaries).

```
PLAN_CONTENT = Read("<plan_path>")
```

Dispatch:

```
Task(
  subagent_type = "productivity:execplan",
  description = "Execute ExecPlan: <plan filename>",
  prompt = "
Execute the following ExecPlan. Follow each milestone in order. Do not prompt the user
for next steps; proceed autonomously. Keep all living document sections up to date.
Commit frequently. Resolve ambiguities autonomously and document decisions in the Decision Log.

<plan_path>
<the plan file path>
</plan_path>

<worktree_path>
<the worktree directory path>
</worktree_path>

<plan>
<the full plan content>
</plan>

<instructions>
- You are working at <worktree_path> on a dedicated branch. All work happens here.
- Update the Progress section in <plan_path> as you complete each step
- Record discoveries in Surprises & Discoveries
- Record decisions in Decision Log

FRESH SUBAGENT PER TASK WITH TWO-STAGE REVIEW:
- Read the plan ONCE and extract ALL tasks with full text upfront
- For each task in the plan, dispatch a FRESH implementer subagent:
  - Inline the full task text + relevant context in the prompt (never make subagents read plan files)
  - Include scene-setting: where the task fits, what was done before, relevant patterns
  - The implementer asks questions before starting, self-reviews before reporting
- After each implementer completes, run TWO sequential reviews:
  1. Spec compliance review: dispatch a fresh reviewer to verify nothing missing, nothing extra
  2. Code quality review: dispatch a fresh reviewer to assess quality and patterns (only after spec passes)
- If a reviewer finds issues: dispatch the implementer to fix → re-review → repeat until approved
- Never dispatch multiple implementers in parallel (causes conflicts)
- Never skip either review stage or proceed while issues remain open

TDD ENFORCEMENT:
- For tasks that introduce or change behavior, follow TDD-first in exact order:
  1. Write failing test (complete code) → 2. Run and verify FAIL → 3. Implement minimal code → 4. Run and verify PASS → 5. Commit
  If you wrote code before its test, delete the implementation and restart with TDD. No exceptions.

COMMIT DISCIPLINE:
- Make atomic commits: each commit should contain exactly one logical change
- Commit frequently using the /commit skill: Skill(skill="commit", args="<concise description>")
- Never use raw git commit or git checkout -b commands — always use the skills
- Do NOT commit the plan file itself — exclude .plans/ and *.plan.md when staging

- At completion, write the Outcomes & Retrospective section
</instructions>
"
)
```

#### Step 3: Create Pull Request

After the agent returns, read the updated plan and report:
- Progress items completed vs remaining
- Any surprises or decisions logged
- Whether the plan is now complete
- The workspace path and branch name

If the plan is complete (all Progress items are checked), create a pull request:

```
Skill(skill="pr", args="<concise PR title derived from the plan's Purpose>")
```

Report the PR URL to the user.

### Resume Mode

#### Step 1: Locate the Workspace

Determine where the plan was executed:

1. Run `git worktree list` to find existing worktrees.
2. Match the worktree by looking for one whose directory name corresponds to the plan slug.
3. If found, store the path as `WORKTREE_PATH` and `cd` into it.
4. If not found, check for the plan's feature branch locally (run `git branch --list` and match by plan slug). If the branch exists, check it out and store the current directory as `WORKTREE_PATH`.
5. If no matching worktree or branch is found, the plan may have been executed on the current branch. Check whether the current branch has commits related to the plan (e.g., `git log --oneline -10` and match against the plan's task description). If so, store the current directory as `WORKTREE_PATH` and continue on the current branch.
6. If none of the above match, ask the user how to proceed using the same workspace question as Execute Mode Step 1. If the branch already exists on the remote, check it out instead of creating a new one.

#### Step 2: Dispatch Resume Agent

Read the plan file content and extract progress context.

```
PLAN_CONTENT = Read("<plan_path>")
```

Parse the Progress section to identify:
- Last completed step (most recent `- [x]`)
- Next incomplete step (first `- [ ]`)

Dispatch:

```
Task(
  subagent_type = "productivity:execplan",
  description = "Resume ExecPlan: <plan filename>",
  prompt = "
Resume execution of an in-progress ExecPlan. The plan has been partially completed.
Review the Progress section to understand what has been done and what remains.
Continue from the first incomplete step.

<plan_path>
<the plan file path>
</plan_path>

<worktree_path>
<the worktree directory path>
</worktree_path>

<plan>
<the full plan content>
</plan>

<resume_context>
Last completed: <last completed step text>
Next to do: <next incomplete step text>
</resume_context>

<instructions>
- You are working at <worktree_path> on a dedicated branch. All work happens here.
- Read the full plan including Surprises & Discoveries and Decision Log for prior context
- Continue from the first incomplete Progress item
- Do not re-execute completed steps
- Update Progress, Surprises, and Decision Log as you go

FRESH SUBAGENT PER TASK WITH TWO-STAGE REVIEW:
- For each remaining task, dispatch a FRESH implementer subagent with full task text inlined
- After each implementer completes, run spec compliance review then code quality review
- Fix issues via review loops before proceeding to next task
- Never skip reviews or proceed while issues remain open

TDD ENFORCEMENT:
- For tasks that introduce or change behavior, follow TDD-first in exact order:
  1. Write failing test (complete code) → 2. Run and verify FAIL → 3. Implement minimal code → 4. Run and verify PASS → 5. Commit
  If you wrote code before its test, delete the implementation and restart with TDD. No exceptions.

COMMIT DISCIPLINE:
- Make atomic commits: each commit should contain exactly one logical change
- Commit frequently using the /commit skill: Skill(skill="commit", args="<concise description>")
- Never use raw git commit or git checkout -b commands — always use the skills
- Do NOT commit the plan file itself — exclude .plans/ and *.plan.md when staging

- At completion, write the Outcomes & Retrospective section
</instructions>
"
)
```

#### Step 3: Create Pull Request

After the agent returns, report status as in Execute Mode. If the plan is now complete, create a pull request:

```
Skill(skill="pr", args="<concise PR title derived from the plan's Purpose>")
```

Report the PR URL to the user.

## Error Handling

- **Plan file not found**: List discovered plans and ask user to select or provide a valid path
- **Agent failure**: Report what happened, suggest checking the plan's Progress section for partial work, and offer to resume
- **No task description**: Prompt for one before dispatching
