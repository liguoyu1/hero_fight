# Test Engineer Templates

## Unit Test Template (Jest)

```javascript
describe('ServiceName', () => {
  describe('methodName', () => {
    it('should return expected result for valid input', () => {
      // Arrange
      const input = 'valid';
      const expected = 'result';
      
      // Act
      const result = service.methodName(input);
      
      // Assert
      expect(result).toBe(expected);
    });

    it('should throw error for invalid input', () => {
      expect(() => service.methodName(null)).toThrow();
    });
  });
});
```

## Integration Test Template

```javascript
describe('API /endpoint', () => {
  beforeAll(async () => {
    // Setup test database, start server
  });

  afterAll(async () => {
    // Cleanup
  });

  it('POST /resource creates new resource', async () => {
    const response = await request(app)
      .post('/resource')
      .send({ name: 'test' })
      .expect(201);
    
    expect(response.body.id).toBeDefined();
  });
});
```

## E2E Test Template (Playwright)

```javascript
test('user flow: login to dashboard', async ({ page }) => {
  await page.goto('/login');
  await page.fill('[data-testid="email"]', 'user@test.com');
  await page.fill('[data-testid="password"]', 'password');
  await page.click('[data-testid="submit"]');
  
  await expect(page).toHaveURL('/dashboard');
  await expect(page.locator('[data-testid="welcome"]')).toBeVisible();
});
```

## CI/CD Test Pipeline (GitHub Actions)

```yaml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      
      - name: Install
        run: npm ci
      
      - name: Lint
        run: npm run lint
      
      - name: Unit Test
        run: npm run test:unit -- --coverage
      
      - name: Integration Test
        run: npm run test:integration
      
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
```

## Test Data Fixtures

```javascript
// fixtures/user.js
export const validUser = {
  id: '1',
  email: 'test@example.com',
  name: 'Test User'
};

export const invalidUser = {
  email: 'invalid-email',
  name: ''
};
```
