---
paths:
  - "**/*.java"
  - "**/pom.xml"
  - "**/build.gradle*"
---

# Java Rules

## Architecture
- Hexagonal Architecture for microservices.
- Domain-Driven Design with clear bounded contexts.

## Style
- `Optional<T>` instead of null returns.
- Custom domain exceptions for business logic errors (e.g., `InsufficientStockException`).
- `GlobalExceptionHandler` for REST endpoints. Problem Details RFC 7807 for error responses.
- Never catch `Exception` broadly; catch specific types.

## Testing
- JUnit 5. Both positive and negative cases.
- Build: `mvn clean package`
- Full test: `mvn verify`

## Dependencies
- Use latest stable versions.
- Conventional commits with scope: `feat(order-service): add saga orchestration`.
