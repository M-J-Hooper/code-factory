---
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
---

# Python Rules

## Toolchain
- Package manager: `uv` (never pip, poetry, conda).
- Linter + formatter: `ruff` (never flake8, black, isort separately).
- Type checker: `mypy`.
- Test runner: `pytest` (via `uv run`).

## Style
- PEP 8 conventions. Type annotations on all function signatures.
- Prefer frozen dataclasses or NamedTuples for immutable data.
- Do not duplicate ruff config in rules; it lives in `pyproject.toml`.

## Commands
- Test: `uv run pytest tests/ -x -q`
- Format: `uv run ruff format .`
- Lint: `uv run ruff check . --fix`
- Install: `uv sync --dev`
