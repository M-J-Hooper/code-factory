# Agent DX Scoring Rubric

Score each axis 0-3. Sum for a total between 0-21.

## 1. Machine-Readable Output

Can an agent parse the CLI's output without heuristics?

| Score | Criteria |
|-------|----------|
| 0 | Human-only output (tables, color codes, prose). No structured format. |
| 1 | `--output json` exists but is incomplete or inconsistent across commands. |
| 2 | Consistent JSON output across all commands. Errors also return structured JSON. |
| 3 | NDJSON streaming for paginated results. Structured output is default in non-TTY contexts. |

### What to check

- Run `<cli> <command> --output json` or `-o json`
- Pipe output: `<cli> <command> | cat` — does it detect non-TTY and switch to JSON?
- Trigger an error: does the error come back as structured JSON?
- List a large collection: does it stream (NDJSON) or buffer the entire array?

## 2. Raw Payload Input

Can an agent send the full API payload without translation through bespoke flags?

| Score | Criteria |
|-------|----------|
| 0 | Only bespoke flags. No way to pass structured input. |
| 1 | `--json` or stdin JSON for some commands, but most require flags. |
| 2 | All mutating commands accept raw JSON that maps to the underlying API schema. |
| 3 | Raw payload is first-class alongside convenience flags. Agent uses API schema docs directly with zero translation. |

### What to check

- Can you pass `--json '{...}'` to create/update commands?
- Does the JSON structure match the underlying API schema (no translation layer)?
- Can you pipe JSON via stdin: `echo '{}' | <cli> create --json -`?
- Are convenience flags still available for human use cases?

## 3. Schema Introspection

Can an agent discover what the CLI accepts at runtime?

| Score | Criteria |
|-------|----------|
| 0 | Only `--help` text. No machine-readable schema. |
| 1 | `--help --json` or `describe` command for some surfaces. |
| 2 | Full schema introspection for all commands — params, types, required fields — as JSON. |
| 3 | Live runtime-resolved schemas from a discovery document. Includes scopes, enums, nested types. |

### What to check

- Run `<cli> schema <command>` or `<cli> <command> --describe`
- Is the output JSON with parameter names, types, required/optional, and descriptions?
- Does it reflect the current API version (not a stale snapshot)?
- Are nested types and enums fully described?

## 4. Context Window Discipline

Does the CLI help agents control response size?

| Score | Criteria |
|-------|----------|
| 0 | Returns full API responses with no way to limit fields or paginate. |
| 1 | `--fields` or field masks on some commands. |
| 2 | Field masks on all read commands. Pagination with `--page-size` or equivalent. |
| 3 | NDJSON streaming pagination. Guidance in context files on field mask usage. |

### What to check

- Run a list command: how large is the default response?
- Is `--fields "id,name"` or `--select` supported?
- Does pagination work? (`--page-size`, `--limit`, `--cursor`)
- For large responses: does it stream or buffer?

## 5. Input Hardening

Does the CLI defend against agent hallucination patterns?

| Score | Criteria |
|-------|----------|
| 0 | No input validation beyond basic type checks. |
| 1 | Some validation, but misses agent-specific hallucination patterns. |
| 2 | Rejects control chars, path traversals (`../`), percent-encoded segments, embedded query params. |
| 3 | All of the above plus output path sandboxing, HTTP-layer encoding. Treats agent as untrusted operator. |

### What to check

- Pass `../../etc/passwd` as a resource ID — does it reject?
- Pass `fileId?fields=name` — does it reject the embedded query params?
- Pass `%2e%2e%2f` — does it detect double encoding?
- Pass strings with control characters (null bytes, newlines) — does it reject?
- Check source code for input sanitization functions

## 6. Safety Rails

Can agents validate before acting?

| Score | Criteria |
|-------|----------|
| 0 | No dry-run. No response sanitization. |
| 1 | `--dry-run` for some mutating commands. |
| 2 | `--dry-run` for all mutating commands. Agent can validate without side effects. |
| 3 | Dry-run plus response sanitization against prompt injection in API data. Full request-response loop defended. |

### What to check

- Run `<cli> delete <resource> --dry-run` — does it validate without executing?
- Does dry-run show what would happen (the request that would be sent)?
- Are API responses filtered before display?
- Is there a confirmation prompt for destructive operations?

## 7. Agent Knowledge Packaging

Does the CLI ship agent-consumable knowledge?

| Score | Criteria |
|-------|----------|
| 0 | Only `--help` and a docs site. No agent-specific context files. |
| 1 | A `CONTEXT.md` or `AGENTS.md` with basic usage guidance. |
| 2 | Structured skill files (YAML frontmatter + Markdown) with per-command workflows. |
| 3 | Comprehensive skill library with agent guardrails. Skills are versioned and follow a standard. |

### What to check

- Look for `CONTEXT.md`, `AGENTS.md`, `.claude/`, `.cursor/rules/` in the repo
- Are there skill files with YAML frontmatter?
- Do the files encode agent-specific invariants ("always use --dry-run", "always add --fields")?
- Are they versioned and maintained alongside the CLI?

## Interpreting the Total

| Range | Rating | Description |
|-------|--------|-------------|
| 0-5 | Human-only | Built for humans. Agents struggle with parsing, hallucinate inputs, lack safety rails. |
| 6-10 | Agent-tolerant | Agents can use it but waste tokens, make avoidable errors, need heavy prompt engineering. |
| 11-15 | Agent-ready | Solid agent support. Structured I/O, input validation, some introspection. A few gaps remain. |
| 16-21 | Agent-first | Purpose-built for agents. Full introspection, hardening, safety rails, packaged knowledge. |

## Bonus: Multi-Surface Readiness

Not scored, but note whether the CLI exposes multiple agent surfaces:

- [ ] **MCP (stdio JSON-RPC)** — typed tool invocation, no shell escaping
- [ ] **Extension / plugin install** — agent treats CLI as native capability
- [ ] **Headless auth** — env vars for tokens/credentials, no browser redirect
