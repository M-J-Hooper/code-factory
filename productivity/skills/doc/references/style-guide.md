# Documentation Style Guide

All documents created or improved by this skill follow these conventions.

## Headings

- Use ATX-style headings (`#`, `##`, etc.)
- One H1 per document (the title)
- No skipped levels (H2 → H4 is invalid, use H2 → H3 → H4)
- Headings should be descriptive, not generic ("Configure Authentication" not "Configuration")

## Links

- Use descriptive link text: `[installation guide](./install.md)` not `[click here](./install.md)`
- Prefer relative links for internal docs: `./setup.md` not absolute URLs
- External links should include context: "See the [official documentation](https://...)"

## Code Blocks

- Always include language identifier: ` ```bash `, ` ```python `, ` ```yaml `
- Use `bash` for shell commands, `shell` for interactive sessions with output
- Use `text` for output-only blocks
- Include comments explaining non-obvious commands

## Admonitions

Use GitHub-style admonitions (compatible with ddoc):

```markdown
> [!NOTE]
> Informational content.

> [!TIP]
> Helpful suggestions.

> [!WARNING]
> Important cautions.

> [!CAUTION]
> Critical warnings about data loss or security.
```

## Frontmatter

For ddoc-enabled documents:

```yaml
---
ddoc:
  confluence_space: "TEAM"
  confluence_parent: "123456"
  title: "Document Title"  # optional, defaults to H1
---
```

## Writing Rules

| Rule | Example |
|------|---------|
| Use active voice | "Run the command" not "The command should be run" |
| Be direct | "Configure X" not "You will need to configure X" |
| Avoid jargon | Define terms on first use or link to glossary |
| Short sentences | Max 25 words per sentence |
| One idea per paragraph | Break complex explanations into steps |
| Present tense | "This command creates..." not "This command will create..." |
