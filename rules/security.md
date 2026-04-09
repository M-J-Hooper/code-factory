# Security

## Secrets
- No hardcoded secrets (API keys, passwords, tokens). Use env vars or secret managers.
- Verify required secrets exist during application startup. Fail fast if missing.
- Never log secrets. Never commit .env files.

## Input Validation
- Validate all user inputs at system boundaries. Never trust external data.
- SQL injection prevention: parameterized queries only.
- XSS prevention: sanitize all HTML output.

## Safety
- When a vulnerability is discovered: STOP, fix critical issues, rotate exposed secrets, review codebase for similar issues.
