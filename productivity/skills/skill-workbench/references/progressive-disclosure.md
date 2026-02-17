# Progressive Disclosure and File Organization

Reference for structuring skills to minimize token usage while maintaining specialized expertise.

## The Three-Level System

Skills use a progressive disclosure model that minimizes context window usage:

| Level | What | When Loaded | Token Impact |
|-------|------|-------------|--------------|
| **1. YAML frontmatter** | Name + description | Always (system prompt) | ~50-100 tokens per skill |
| **2. SKILL.md body** | Full instructions | When Claude thinks skill is relevant | Hundreds to thousands |
| **3. Linked files** | Reference docs, scripts, templates | Only when Claude navigates to them | On-demand |

**Key insight:** Only accessed files consume context tokens. A skill with 5 reference files costs nothing extra until Claude reads one.

## File Organization Patterns

### Self-Contained Skill (most common)

```
skill-name/
  SKILL.md    # Everything inline
```

**When:** All content fits under 500 lines. No heavy reference material needed.

### Skill with Reference Files

```
skill-name/
  SKILL.md              # Core instructions (under 500 lines)
  references/
    api-patterns.md     # Detailed API reference
    examples.md         # Extended examples
    templates.md        # Reusable templates
```

**When:** Reference material exceeds 100 lines. Separate by domain or purpose.

### Skill with Executable Tools

```
skill-name/
  SKILL.md              # Instructions referencing scripts
  scripts/
    validate.py         # Validation script
    generate.sh         # Generation utility
```

**When:** Skill includes reusable code. Scripts offer reliability and token efficiency over generated code.

## Critical Rules

| Rule | Rationale |
|------|-----------|
| Keep references one level deep from SKILL.md | Deeper nesting risks Claude not finding files |
| SKILL.md body under 500 lines | Loaded entirely when triggered — every line costs tokens |
| Reference files linked explicitly | `See [references/api-guide.md](references/api-guide.md)` — Claude needs to know they exist |
| No README.md inside skill folders | All documentation goes in SKILL.md or references/ |
| Separate files by domain, not by type | `finance.md` and `sales.md` not `rules.md` and `examples.md` |

## Degrees of Freedom

Match instruction precision to task requirements:

### Low Freedom (exact scripts)

Use for fragile operations, destructive commands, critical validation.

```markdown
## Step 3: Validate

Run exactly:
\`\`\`bash
make all
\`\`\`

Expected output: `All checks passed.`
If output differs, read the error and fix the specific issue.
```

### Medium Freedom (pseudocode templates)

Use for multi-step workflows with some variability.

```markdown
## Step 2: Evaluate Changes

For each changed file:
1. Run `git diff --stat` to identify scope
2. Check against these criteria:
   - No unintended modifications outside target area
   - New code follows existing patterns
   - No debug statements remain
3. Record findings as: `file | dimension | description`
```

### High Freedom (guidelines)

Use for context-dependent judgment calls.

```markdown
## Step 1: Determine Scope

Analyze the user's request and identify:
- Which files are affected
- Whether changes are additive or modifying existing behavior
- The appropriate level of testing needed

Use your judgment based on the complexity and risk of the change.
```

## Token Optimization Techniques

| Technique | Savings | Example |
|-----------|---------|---------|
| **Move details to --help** | High | "Run `cmd --help` for flags" vs listing all flags |
| **Cross-reference skills** | Medium | "See `/commit` for conventions" vs duplicating content |
| **Tables over paragraphs** | Medium | 3 table rows < 3 paragraphs |
| **Compress examples** | Low-Medium | Minimal example showing the same pattern in fewer words |
| **Remove Claude-known content** | High | Don't explain what git commands do |

## Conditional Loading Pattern

For skills that serve multiple audiences or modes:

```markdown
## Step 1: Determine Mode

If user wants X → follow Step 2a
If user wants Y → follow Step 2b

## Step 2a: Mode X

Consult [references/mode-x-guide.md](references/mode-x-guide.md) for detailed instructions.

## Step 2b: Mode Y

Consult [references/mode-y-guide.md](references/mode-y-guide.md) for detailed instructions.
```

Only the relevant reference file gets loaded, saving tokens for the irrelevant path.

## Sources

- [Anthropic: The Complete Guide to Building Skills for Claude](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)
- [Anthropic: Skills Best Practices](https://docs.anthropic.com/en/docs/agents-and-tools/agent-skills/best-practices)
