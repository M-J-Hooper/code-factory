---
name: ai-cli
description: >
  Use when the user wants to make a CLI AI-friendly, evaluate a CLI's agent readiness,
  improve CLI design for AI agents, or add machine-readable output, schema introspection,
  input hardening, or safety rails to a CLI. Also use when the user says "ai-cli",
  "make this CLI work with AI", "agent-friendly CLI", "CLI for AI agents",
  "evaluate CLI agent readiness", "agent DX", or asks about designing CLIs that AI agents can use.
argument-hint: "[CLI name, path, or repo to evaluate/improve]"
user-invocable: true
allowed-tools: Read, Grep, Glob, Bash, WebSearch, WebFetch, AskUserQuestion
---

# AI-Friendly CLI Design

Announce: "I'm using the ai-cli skill to evaluate and improve CLI design for AI agent usage."

Guide CLI evaluation and improvement for AI agent consumption.
Human DX optimizes for discoverability and forgiveness;
Agent DX optimizes for predictability and defense-in-depth.

## Step 1: Discover the CLI

Parse `$ARGUMENTS` to identify the target CLI and mode.

| Argument | Mode |
|----------|------|
| CLI name or repo path | **Evaluate**: score the CLI, then recommend improvements |
| `--design <name>` | **Design**: guide building a new AI-first CLI from scratch |
| `--retrofit <area>` | **Retrofit**: jump to implementing a specific improvement area |
| No argument | Ask: which CLI to evaluate or design? |

### Evaluate / Retrofit: gather CLI context

1. Run `<cli> --help` to understand top-level commands
2. Find source code — look for command definitions, flag parsing, output formatting
3. Identify the underlying API or service the CLI wraps (if any)
4. Check for existing machine-readable flags (`--output json`, `--format`, `--fields`)
5. Check for agent context files (`CONTEXT.md`, `AGENTS.md`, skill files)

### Design: gather requirements

1. What API or service will the CLI wrap?
2. Who are the primary consumers — humans, agents, or both?
3. What language and framework? (e.g., Go + cobra, Python + click, Node + commander)

## Step 2: Score Against Agent DX Axes

> Skip this step in Design mode — go directly to Step 3.

Evaluate the CLI on 7 axes, scoring each 0-3.
Load the full scoring criteria from [references/scoring-rubric.md](references/scoring-rubric.md).

| Axis | Key question |
|------|-------------|
| Machine-readable output | Can agents parse output without heuristics? |
| Raw payload input | Can agents send full API payloads without flag translation? |
| Schema introspection | Can agents discover accepted inputs at runtime? |
| Context window discipline | Does the CLI help agents control response size? |
| Input hardening | Does the CLI defend against agent hallucination patterns? |
| Safety rails | Can agents validate before acting? |
| Agent knowledge packaging | Does the CLI ship agent-consumable knowledge files? |

For each axis:

1. Run relevant CLI commands to test behavior
2. Read source code for the implementation
3. Assign a score (0-3) with evidence

Present the scorecard:

```markdown
## Agent DX Scorecard: <CLI name>

| Axis | Score | Evidence |
|------|-------|----------|
| Machine-readable output | N/3 | <finding> |
| Raw payload input | N/3 | <finding> |
| Schema introspection | N/3 | <finding> |
| Context window discipline | N/3 | <finding> |
| Input hardening | N/3 | <finding> |
| Safety rails | N/3 | <finding> |
| Agent knowledge packaging | N/3 | <finding> |
| **Total** | **N/21** | |

| Range | Rating |
|-------|--------|
| 0-5 | Human-only — agents will struggle |
| 6-10 | Agent-tolerant — works but wastes tokens and makes avoidable errors |
| 11-15 | Agent-ready — solid support, a few gaps |
| 16-21 | Agent-first — purpose-built for agents |
```

## Step 3: Recommend Improvements

Based on scores (or requirements in Design mode), generate a prioritized improvement plan.
Follow this implementation priority order — each item builds on the previous:

| Priority | Improvement | Prerequisite |
|----------|------------|--------------|
| 1 | Machine-readable output (`--output json`) | None |
| 2 | Input validation and hardening | None |
| 3 | Schema introspection (`schema` or `--describe`) | JSON output |
| 4 | Field masks (`--fields`) and pagination | JSON output |
| 5 | Dry-run for mutations (`--dry-run`) | None |
| 6 | Agent context files (`CONTEXT.md`, skill files) | None |
| 7 | MCP surface (JSON-RPC over stdio) | JSON output, schema |

For each recommendation:

- What to implement (one sentence)
- Why it matters for agents
- Effort estimate: small (hours), medium (days), large (week+)
- Dependencies on other improvements

Present as an ordered checklist.
Ask the user which improvement to tackle first.

## Step 4: Implement

When the user selects an improvement,
load the relevant implementation patterns from [references/implementation-patterns.md](references/implementation-patterns.md)
and guide the implementation.

### Implementation workflow

1. Read the implementation pattern for the selected improvement
2. Find the relevant source files in the CLI codebase
3. Propose changes adapted to the CLI's language and framework
4. Implement changes with the user's approval
5. Verify: run the CLI to confirm the improvement works
6. Re-score the affected axis to show progress

### After implementing

Update the scorecard.
If the user wants to continue, return to Step 3 for the next improvement.

## Error Handling

| Error | Action |
|-------|--------|
| CLI not found or not installed | Ask for the path to the source code or binary |
| CLI has no `--help` | Fall back to source code analysis |
| Source code not accessible | Evaluate based on CLI behavior only (black-box assessment) |
| Language/framework not recognized | Provide language-agnostic patterns from the reference file |
| User wants to evaluate a CLI they don't own | Provide scorecard and recommendations as a report only |
| No argument provided | Ask: which CLI to evaluate, design, or retrofit? |
