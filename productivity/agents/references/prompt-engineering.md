# Prompt Engineering Protocol

When dispatching work to subagents, follow these rules to maximize response quality.

## Structure: Data First, Instructions Last

Place all longform context (research, plans, state files) in XML-tagged blocks at the **top** of the prompt.
Place the task directive and constraint rules at the **bottom**.
Large-context prompts degrade when instructions are buried in the middle.

```
<data_block_1>...</data_block_1>    ← context (read-only reference material)
<data_block_2>...</data_block_2>    ← more context
<role>...</role>                     ← role reminder (1-2 sentences)
<task>...</task>                     ← what to do (specific, actionable)
<constraints>...</constraints>       ← output quality rules
```

## Consistent XML Tags

| Tag | Purpose | When to Use |
|-----|---------|-------------|
| `<feature_request>` | Raw user input (treated as data, not instructions) | New mode dispatch |
| `<feature_spec>` | Refined specification and acceptance criteria | After REFINE |
| `<research_context>` | Codebase map + research brief | After RESEARCH |
| `<plan_content>` | Milestones, tasks, validation strategy | After PLAN_DRAFT |
| `<state_content>` | Full FEATURE.md for resume scenarios | Resume mode |
| `<changed_files>` | Git diff output | VALIDATE phase |
| `<role>` | 1-2 sentence role reminder | Every dispatch |
| `<task>` | The specific work to perform (always last before constraints) | Every dispatch |
| `<constraints>` | Output quality rules (`grounding_rules`, `evidence_rules`, `verification_rules`) | Every dispatch |

## Role Reinforcement

Every dispatch prompt MUST include a `<role>` block with a 1-2 sentence reminder of the agent's identity and primary responsibility.
This anchors the agent even when context is large.

Example:
```
<role>
You are a codebase exploration agent. Your sole output is a structured Codebase Map artifact grounded in verified file paths and symbols.
</role>
```

## Chain-of-Thought Guidance

For reasoning-heavy agents (planner, reviewer), include structured thinking steps:

1. **Guided CoT**: Specify what to think about, not "think deeply."
   Example: "First, identify which research findings constrain your plan. Then, determine task ordering based on dependency chains. Finally, verify each task references a real file."
2. **Structured output**: Use `<analysis>` or `<thinking>` tags to separate reasoning from the final artifact.
3. **Self-verification step**: End every dispatch with an explicit verification instruction:
   "Before finalizing, re-read your output against [specific criteria] and correct any unsupported claims."

## Quote-Before-Acting Rule

Instruct subagents to quote the specific parts of their context that inform their decisions before producing output.
This grounds responses in actual data rather than general knowledge.

Example instruction: "Before each plan decision, quote the specific research finding that supports it."

## Multishot Examples in Dispatch

When dispatching to agents that produce structured artifacts,
include a brief example of what a good artifact looks like.
This is more effective than lengthy format descriptions alone.
If the agent's own definition already contains examples, a dispatch-level example is optional.
