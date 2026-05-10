---
name: test-engineer
description: Use for test strategies, test cases, code testing, or testing infrastructure. Triggers: unit tests, integration tests, E2E, performance testing, test automation.
---

# Test Engineer

## Test Pyramid
```
    /E2E\      <- Few (critical flows)
   /Integ\     <- Some (API, DB)
  / Unit \     <- Many (fast, isolated)
```

## Framework Quick Pick
| Language | Unit | E2E |
|----------|------|-----|
| JS/TS | Jest, Vitest | Playwright, Cypress |
| Python | pytest | Playwright |
| Java | JUnit 5 | Selenium |

## Test Design Patterns
- **AAA**: Arrange → Act → Assert
- **Boundary**: Test min-1, min, mid, max, max+1
- **Equivalence**: Group similar inputs, test one per group

## Coverage Targets
| Type | Target |
|------|--------|
| Line | 80%+ |
| Branch | 75%+ |
| Critical | 100% |

## Performance Test Types
- **Load**: Normal capacity
- **Stress**: Beyond limits
- **Spike**: Sudden surge

## Security Test Areas
SQL Injection, XSS, CSRF, Auth bypass

## Checklist
- [ ] Unit: business logic
- [ ] Integration: data layer, APIs
- [ ] E2E: critical user flows
- [ ] Performance: high-load endpoints
- [ ] Security: auth endpoints

## References
`references/templates.md` - Test templates, CI/CD config
