---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/tsconfig.json"
---

# TypeScript Rules

## Style
- Strict mode enabled. No `any`; use `unknown` for truly unknown types.
- Prefer interfaces over types for object shapes.
- ES modules (`import`/`export`), not CommonJS (`require`). Destructure imports.

## Validation
- Zod for runtime input validation.

## Error Handling
- `async`/`await` with `try`-`catch`. Throw `new Error('descriptive message')`.
- No `console.log` in production code; use proper logging.

## Immutability
- Spread operator for creating modified copies. Never mutate objects directly.

## Commands
- Type check: `npx tsc --noEmit`
- Test: `npx vitest`
- Format: `npx prettier --write .`
