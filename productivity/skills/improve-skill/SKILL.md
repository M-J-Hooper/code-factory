---
name: improve-skill
description: >
  Use when the user wants to reflect on recent work and improve the skills, tools,
  and documentation in this plugin marketplace. Accepts an optional focus area
  argument to narrow scope to a specific plugin, skill, or category.
  Triggers: "improve skills", "improve tools", "make skills better",
  "reflect and improve", "improve the repo", "audit skills", "polish skills",
  "skill quality".
argument-hint: "[optional focus area: skills, docs, tools, or specific plugin name]"
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Edit, Grep, Glob, Task
---

# Improve Skills and Tools

Announce: "I'm using the improve skill to reflect on recent work and improve the skills, tools, and documentation in this repo."

## Step 1: Gather Context

Run in parallel:

- `git rev-parse --show-toplevel` (confirm repo root)
- `git log --oneline -10` (recent work for context)

Then discover repo assets (run Glob calls in parallel):

- `**/skills/*/SKILL.md` (all skills)
- `**/.claude-plugin/plugin.json` (all plugin manifests)
- `**/agents/*.md` (agent definitions)

Read each plugin's `plugin.json` to note current versions (needed for version bumps later).

Read `AGENTS.md` for current repo conventions.

**If not in the code-factory repo:** inform the user this skill is designed for the code-factory plugin marketplace and stop.

## Step 2: Reflect on Recent Experience

Review the session's work by examining concrete artifacts:

1. Run `git log --oneline -20` and `git diff HEAD~5..HEAD --stat` to identify which files changed recently.
2. For each changed skill, read it and evaluate against the four dimensions below.
3. If `$ARGUMENTS` specifies a focus area, narrow to that area only.
4. If there is no recent session context, ask the user what area to improve or offer a general audit of all skills.

### Evaluation Dimensions

| Dimension | Key Question | How to Check |
|-----------|-------------|--------------|
| **Friction** | Where did you hesitate or get confused? | Re-read skill instructions as if encountering them for the first time |
| **Token waste** | What content is verbose or redundant? | Look for paragraphs that could be tables, repeated information across skills |
| **Missing pieces** | What manual steps should be automated? | Check for error cases not covered, skills that should exist but don't |
| **Confusion** | What instructions are ambiguous? | Look for vague verbs ("handle", "process", "deal with") without specific actions |

For each finding, note: the file, the dimension, and a one-sentence description.

## Step 3: Make Improvements

Apply changes directly. You have full authority to improve any file in this repo. Do not ask permission for improvements within existing files.

Prioritize improvements in this order:

1. **Critical**: broken cross-references, missing error handling, incorrect instructions
2. **Functional**: vague instructions, missing edge cases, inconsistent patterns
3. **Polish**: filler word removal, table formatting, redundant content

### Improving Skills

**Location:** `{plugin}/skills/{name}/SKILL.md`

Read `references/skill-quality-checklist.md` for quality criteria, filler words list, before/after examples, and Definition of Done checklist. Apply each criterion.

**Version bump required:** Any change to a skill or agent file requires a version bump in the owning plugin's `.claude-plugin/plugin.json` (patch for fixes, minor for new features).

### Improving Documentation

**Files:** `AGENTS.md`, `README.md`, skill `SKILL.md` files

- Keep instructions actionable and specific (commands, not descriptions)
- Remove ambiguity that caused confusion during your session
- Add missing conventions you discovered

### Improving Tools

**Files:** `Makefile`, `init.sh`, config files

- Minimal output on success, clear messages on failure
- Sensible defaults, fail fast
- Add missing validation targets if gaps are found

### Creating New Skills or Plugins

Read `references/new-skill-template.md` for creation checklists and YAML templates.

**For significant new features**, suggest running `/execplan` first instead of implementing inline.

## Step 4: Validate

Run after all changes:

```bash
make all
```

### Iteration Loop

If `make all` fails:

1. Read the error output to identify which check failed.
2. Fix the specific issue (do not make unrelated changes).
3. Re-run `make all`.
4. Repeat until all checks pass. Maximum 3 iterations — if still failing after 3 attempts, report the remaining failures to the user.

### Manual Quality Checks

After `make all` passes, verify these criteria (not covered by automated checks):

| Check | How to Verify |
|-------|---------------|
| First-read clarity | Re-read each updated skill as if seeing it for the first time — is every step unambiguous? |
| No filler words | Search updated files for: simply, just, easily, basically, actually, really, very |
| Naming conventions | New files follow `{plugin}/skills/{name}/SKILL.md` pattern |
| Description convention | All descriptions start with "Use when" |

## Step 5: Report

Present a summary of all changes. For non-trivial improvements, include a brief before/after snippet.

<report-template>
## Improvements Made

### Skills Updated
- **{plugin}:{skill-name}**: {what changed and why}
  - Before: {brief excerpt}
  - After: {brief excerpt}

### Documentation Updated
- **{file}**: {what changed and why}

### Tools Improved
- **{tool}**: {what changed and why}

### New Skills Created
- **{plugin}:{skill-name}**: {what it does}

### Version Bumps
- **{plugin}**: {old} -> {new}

### Suggested Follow-ups
- {anything that needs deeper work via /execplan}
</report-template>

Omit any section with no entries.

## Example

<example>

### Invocation

    /improve-skill git

### What Happens

1. Gathers all skills in the `git/` plugin and reads current versions.
2. Reviews `git log` for recent changes to git skills.
3. Finds: `/commit` Step 2 says "Analyze changes" without specifying *what* to analyze.
4. Reads `references/skill-quality-checklist.md` — flags the vague instruction under "Friction" dimension.
5. Rewrites Step 2 with an explicit list of analysis targets (title, documentation links, motivation, summary).
6. Runs `make all` — passes.
7. Reports the improvement with before/after.

### Sample Report

    ## Improvements Made

    ### Skills Updated
    - **git:commit**: Step 2 now lists specific analysis targets instead of vague "Analyze changes"
      - Before: "Analyze the staged changes"
      - After: "For each staged file, identify: title line, documentation links, motivation, summary"

    ### Version Bumps
    - **git**: 0.3.0 -> 0.3.1

</example>

## Error Handling

| Error | Action |
|-------|--------|
| Not in code-factory repo | Inform the user this skill is designed for the code-factory plugin marketplace. Stop. |
| No recent session context and no focus area | Ask the user what area to improve, or offer a general audit of all skills. |
| `make all` failure after 3 fix attempts | Report remaining failures to the user with the specific error output. Do not loop indefinitely. |
| Multiple plugins need version bumps | Bump each plugin independently. Run `make check-versions` to verify each bump. |
| Broken cross-reference to non-existent skill | If the referenced skill should exist, create it (see `references/new-skill-template.md`). If not, fix the reference. |
| Significant interface change | Describe the proposed change (skill name, arguments, behavior) and ask the user before applying. |
| Reference file missing | Proceed using inline principles: concise, scannable, complete, consistent, self-contained. |
