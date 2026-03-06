# Testing

## Workflow
- TDD when behavior changes: write test (RED) -> verify failure -> implement (GREEN) -> refactor.
- When tests fail, fix the implementation -- not the tests (unless tests have errors).
- Run single tests during development, not the whole suite.

## Coverage
- Both positive and negative test cases for every feature.
- Mock external dependencies; never call real APIs in tests.
- Test names: "should [action] when [condition]".

## Verification
- Give Claude a way to verify its work. Tests are the best verification mechanism.
- After implementing, always run the relevant test command before considering work done.
