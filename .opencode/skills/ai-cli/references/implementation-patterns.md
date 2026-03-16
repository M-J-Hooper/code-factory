# Implementation Patterns

Concrete patterns for each Agent DX improvement area.
Language-agnostic principles with examples in Go (cobra) and Python (click).

## 1. Machine-Readable Output

### Dual-format output

Add a global `--output` flag. In non-TTY contexts (piped), default to JSON.

```go
// Go + cobra
var outputFormat string

func init() {
    rootCmd.PersistentFlags().StringVarP(&outputFormat, "output", "o", "", "Output format: json, table (default: auto)")
}

func printOutput(data any) {
    format := outputFormat
    if format == "" {
        if isatty.IsTerminal(os.Stdout.Fd()) {
            format = "table"
        } else {
            format = "json"
        }
    }
    switch format {
    case "json":
        enc := json.NewEncoder(os.Stdout)
        enc.SetIndent("", "  ")
        enc.Encode(data)
    default:
        printTable(data)
    }
}
```

```python
# Python + click
@click.option('--output', '-o', type=click.Choice(['json', 'table']), default=None)
def cli(output):
    if output is None:
        output = 'json' if not sys.stdout.isatty() else 'table'
```

### Structured errors

Return errors as JSON with a consistent schema. Never exit 0 on error.

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Resource 'abc123' not found",
    "details": {"resource_type": "file", "resource_id": "abc123"}
  }
}
```

Exit codes: 0 = success, 1 = usage error, 2 = runtime error.

## 2. Input Validation and Hardening

### Input sanitizer middleware

Validate all string inputs before they reach business logic.

```go
func validateResourceID(id string) error {
    if strings.Contains(id, "..") {
        return fmt.Errorf("path traversal detected in resource ID: %q", id)
    }
    if strings.ContainsAny(id, "?#") {
        return fmt.Errorf("embedded query params in resource ID: %q", id)
    }
    if strings.Contains(id, "%") {
        return fmt.Errorf("percent-encoded value in resource ID: %q — pass decoded values", id)
    }
    for _, r := range id {
        if r < 0x20 {
            return fmt.Errorf("control character in resource ID: %q", id)
        }
    }
    return nil
}
```

### Hallucination patterns to catch

| Pattern | Detection | Example |
|---------|-----------|---------|
| Path traversal | `..` in resource IDs or paths | `../../.ssh/id_rsa` |
| Embedded query params | `?` or `#` in resource IDs | `fileId?fields=name` |
| Double encoding | `%` in decoded inputs | `%2e%2e` for `..` |
| Control characters | ASCII < 0x20 | Null bytes, newlines in IDs |
| Overly long inputs | Length exceeds reasonable max | 10KB resource ID |

## 3. Schema Introspection

### `schema` subcommand

Add a `schema <method>` command returning the full method signature as JSON.

```json
{
  "method": "files.create",
  "http_method": "POST",
  "path": "/v1/files",
  "parameters": {
    "parent_id": {"type": "string", "required": true, "description": "Parent folder ID"},
    "name": {"type": "string", "required": true, "description": "File name"}
  },
  "request_body": {
    "type": "object",
    "properties": {
      "content": {"type": "string"},
      "mime_type": {"type": "string", "default": "text/plain"}
    }
  },
  "response": {
    "type": "object",
    "properties": {
      "id": {"type": "string"},
      "name": {"type": "string"},
      "created_at": {"type": "string", "format": "date-time"}
    }
  },
  "scopes": ["files:write"]
}
```

### Generate from source of truth

Generate schema from an OpenAPI spec, protobuf definition, or API discovery document.
Avoids schema drift — the CLI always reflects the current API.

## 4. Field Masks and Pagination

### `--fields` flag

Accept a comma-separated list of fields to include in the response.

```go
var fields string
cmd.Flags().StringVar(&fields, "fields", "", "Comma-separated fields to include (e.g., id,name,status)")

// Filter response before output
if fields != "" {
    data = filterFields(data, strings.Split(fields, ","))
}
```

### NDJSON streaming pagination

Stream results as newline-delimited JSON instead of buffering entire arrays.

```go
func streamResults(w io.Writer, paginator Paginator) error {
    enc := json.NewEncoder(w)
    for paginator.HasNext() {
        page, err := paginator.Next()
        if err != nil {
            return err
        }
        for _, item := range page.Items {
            if err := enc.Encode(item); err != nil {
                return err
            }
        }
    }
    return nil
}
```

## 5. Dry-Run Mode

### `--dry-run` flag on all mutations

Show what would happen without executing. Output: HTTP method, URL, headers, body, validation results.

```go
var dryRun bool
cmd.Flags().BoolVar(&dryRun, "dry-run", false, "Validate and show what would happen without executing")

func executeOrDryRun(req *http.Request, dryRun bool) error {
    if dryRun {
        out := map[string]any{
            "method":  req.Method,
            "url":     req.URL.String(),
            "headers": req.Header,
        }
        if req.Body != nil {
            body, _ := io.ReadAll(req.Body)
            out["body"] = json.RawMessage(body)
        }
        return json.NewEncoder(os.Stdout).Encode(out)
    }
    return execute(req)
}
```

## 6. Agent Context Files

### `CONTEXT.md` at repo root

```markdown
# <CLI Name> Agent Context

## Quick Start

<one command to get started>

## Invariants

- Always use `--output json` when parsing output programmatically
- Always add `--fields` to list commands to limit response size
- Always use `--dry-run` before mutating commands
- Never pass user-generated content as resource IDs without validation

## Common Workflows

### Create a resource
<cli> create --json '{"name": "example"}' --dry-run
<cli> create --json '{"name": "example"}'

### List with pagination
<cli> list --fields id,name,status --page-size 50 --output json
```

### Structured skill files

Ship YAML-frontmatter Markdown files for agent-specific workflows:

```yaml
---
name: <cli>-create-resource
version: 1.0.0
---

# Create Resource

1. Validate input: `<cli> schema resources.create`
2. Dry-run: `<cli> resources create --json '{...}' --dry-run`
3. Execute: `<cli> resources create --json '{...}'`
4. Verify: `<cli> resources get <id> --fields id,status`
```

## 7. MCP Surface

### JSON-RPC over stdio

Expose the CLI as an MCP server for direct agent integration.

```json
{
  "mcpServers": {
    "<cli-name>": {
      "command": "<cli>",
      "args": ["mcp", "serve"],
      "env": {"API_KEY": "..."}
    }
  }
}
```

Each CLI command becomes an MCP tool with typed parameters derived from the schema.
Eliminates shell escaping, argument parsing ambiguity, and output parsing.

### Implementation approach

1. Define tools from the same source of truth as CLI commands (OpenAPI, protobuf, discovery doc)
2. Map each command to a tool with typed input/output schemas
3. Handle auth via environment variables (headless — no browser redirect)
4. Return structured JSON responses, not formatted text
