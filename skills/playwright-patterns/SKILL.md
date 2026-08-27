---
name: playwright-patterns
description: Playwright E2E testing patterns — Page Object Model, fixtures, configuration, flaky-test diagnosis and cures, CI/CD integration, artifact management (traces/screenshots/videos), critical-flow testing (financial, wallet/web3). Activate when writing or reviewing Playwright tests, structuring page objects, configuring playwright.config, fixing flaky E2E runs, or wiring E2E suites into CI.
---

# Playwright E2E Patterns

Patterns for stable, fast, maintainable Playwright suites. Target: `@playwright/test`
(the test runner, not bare playwright-core).

## When to Activate

- Writing or refactoring Playwright tests / page objects / fixtures
- Creating or tuning `playwright.config.ts`
- Diagnosing flaky E2E tests, locally or in CI
- Wiring E2E into CI, managing traces/screenshots/videos
- Trigger phrases: "Playwright", "E2E", "page object", "flaky test", "автотесты", "браузерные тесты"

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| Test layout, Page Object Model, fixtures, test structure | [references/pom.md](references/pom.md) |
| playwright.config.ts, projects matrix, webServer, reporters, timeouts | [references/config.md](references/config.md) |
| Flaky tests: identify, diagnose by cause, quarantine protocol | [references/flaky.md](references/flaky.md) |
| CI workflows, artifact upload/retention, report template | [references/ci-artifacts.md](references/ci-artifacts.md) |
| Financial/destructive flows, wallet & web3 mocking | [references/critical-flows.md](references/critical-flows.md) |

## Core Principles

1. **Semantic locators.** `getByRole` / `getByLabel` / `getByTestId` / `[data-testid=…]`.
   CSS chains are brittle, XPath is banned. No test hook on the element → add
   `data-testid` to the app markup.
2. **Wait for conditions, never for time.** `expect(locator).toBeVisible()`,
   `waitForResponse`, `waitForLoadState('networkidle')`. `waitForTimeout` only inside a
   quarantined test awaiting a real fix.
3. **Auto-waiting API only.** `page.locator(x).click()` auto-waits; bare `page.click(x)`
   doesn't — never use it.
4. **Independent tests.** Each test seeds its own state and passes alone, in any order,
   in parallel. Shared login → `storageState` fixture, not a login test other tests
   depend on.
5. **Assert at key steps.** A 20-action journey with one final assert localizes nothing.
6. **Artifacts on failure, always.** `trace: 'on-first-retry'`,
   `screenshot: 'only-on-failure'`, `video: 'retain-on-failure'` — debugging a CI red must
   not require a local rerun.
7. **Retries mask, sleeps postpone.** Neither is a fix — see flaky.md for cause-level cures.

## Quick Reference

| Need | Pattern |
|---|---|
| Click when ready | `await page.locator('[data-testid="btn"]').click()` |
| Wait for API | `await page.waitForResponse(r => r.url().includes('/api/x') && r.status() === 200)` |
| Check flakiness | `npx playwright test spec.ts --repeat-each=10` |
| Quarantine | `test.fixme(true, 'Flaky — Issue #123')` |
| Skip per env | `test.skip(process.env.NODE_ENV === 'production', 'destructive')` |
| Debug a failure | `npx playwright show-trace trace.zip` / `npx playwright test --debug` |
| Auth once, reuse | `storageState` in a fixture / `globalSetup` |
