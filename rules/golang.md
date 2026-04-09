---
paths:
  - "**/*.go"
  - "**/go.mod"
  - "**/go.sum"
---

# Go Rules

## Style
- gofmt and goimports are mandatory. No style debates.
- Avoid stutter: `package kv; type Store` (not `KVStore`).
- Input structs for functions with >2 arguments.
- Favor standard library; introduce dependencies only with clear justification.

## Interfaces
- Accept interfaces, return structs. Define interfaces where used, not where implemented.
- Keep interfaces small (1-3 methods). Composition over inheritance.

## Errors
- Wrap with context: `fmt.Errorf("failed to X: %w", err)`.
- Use `errors.Is`/`errors.As` for control flow; never match error strings.
- Define sentinel errors in package; document behavior.

## Concurrency
- `context.Context` as first parameter; never store in structs. Honor Done/deadlines.
- Tie goroutine lifetime to context. Use `errgroup` for fan-out; cancel on first error.
- Sender closes channels; receivers never close. Protect shared state with `sync.Mutex`/`atomic`.

## Testing
- Table-driven tests. Run with `-race`. Use `t.Cleanup` for teardown. Mark safe tests with `t.Parallel()`.

## Observability
- Structured logging with `slog`. Correlate logs/metrics/traces via request IDs from context.

## Build
- Test: `go test -race ./...`
- Lint: `golangci-lint run`
- Config via env/flags; validate on startup; fail fast.
