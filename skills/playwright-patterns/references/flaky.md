# Flaky Tests — Identify, Diagnose, Cure

A flaky test is worse than no test: it trains the team to ignore red. Protocol: reproduce
→ diagnose from the trace → fix the cause → only then, if unfixable now, quarantine with
an issue reference.

## Identify

```bash
npx playwright test spec.ts --repeat-each=10              # does it flake at all?
npx playwright test spec.ts --repeat-each=10 --workers=1  # separates parallelism from timing
npx playwright show-trace test-results/**/trace.zip       # what actually happened
```

New or changed tests: `--repeat-each=3` minimum before declaring done, 5 for anything
timing-sensitive.

## Causes and cures

**Race condition — action before element ready:**
```typescript
// Bad: no auto-wait
await page.click('[data-testid="button"]')

// Good: locator API auto-waits for visible/enabled/stable
await page.locator('[data-testid="button"]').click()
```

**Network timing — asserting before the response landed:**
```typescript
// Bad: arbitrary sleep
await page.waitForTimeout(5000)

// Good: wait for the actual condition
await page.waitForResponse(r => r.url().includes('/api/data') && r.status() === 200)
```

**Animation — clicking a moving target:**
```typescript
// Good: wait for stability first
const item = page.locator('[data-testid="menu-item"]')
await item.waitFor({ state: 'visible' })
await page.waitForLoadState('networkidle')
await item.click()
```

**Assertion race — pulling a value out instead of retrying assert:**
```typescript
// Bad: reads once, races the render
expect(await itemCards.count()).toBe(3)

// Good: web-first assertion retries until timeout
await expect(itemCards).toHaveCount(3)
```

**Shared state — test order dependence:** each test seeds its own data with unique keys;
run the pair `--workers=1` vs parallel to confirm; fix by isolation, not by ordering.

**Environment drift — locale/timezone/viewport:** pin all three in `use:` (see config.md).
Dates and i18n strings are the classic "passes locally, fails in CI".

**App-level nondeterminism** (random content, third-party widgets, ads): mock the source
via `page.route()` — a test asserting on nondeterministic content cannot be stable.

## Quarantine

```typescript
test('market search ranking', async ({ page }) => {
  test.fixme(true, 'Flaky — Issue #123: search index race')
  // ...
})

test('heavy export', async ({ page }) => {
  test.skip(!!process.env.CI, 'Flaky in CI only — Issue #124')
  // ...
})
```

Rules:
- Quarantine **always** carries an issue reference — an unreferenced `fixme` is where
  tests go to die. No tracker → at minimum a dated TODO with the diagnosis.
- Quarantined tests are counted and reported every run (they appear in the coverage
  matrix's "Stale & quarantined" section), not forgotten.
- Retries (`retries: 2` in CI) are a detection net — Playwright marks retried-then-passed
  tests "flaky" in the report. Watch that count; rising = suite rotting.
- Never "fix" a flake by adding `waitForTimeout` or raising retries — both hide the cause
  and slow every run.
