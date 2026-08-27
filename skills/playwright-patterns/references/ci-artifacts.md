# CI Integration & Artifacts

## GitHub Actions

```yaml
name: E2E Tests
on: [push, pull_request]

permissions:
  contents: read

jobs:
  e2e:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test
        env:
          BASE_URL: ${{ vars.STAGING_URL }}
      - uses: actions/upload-artifact@v4
        if: always()                      # report uploads on failure too — that's the point
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 30
```

Notes:
- `npx playwright install --with-deps <browser>` installs only the browsers the config
  uses — installing all three when only chromium runs wastes minutes per run.
- Cache note: browser binaries can be cached keyed on the Playwright version
  (`~/.cache/ms-playwright`), but a cold install is often comparable — measure before adding.
- Sharding for big suites: matrix over `shard: [1/3, 2/3, 3/3]`,
  `npx playwright test --shard=${{ matrix.shard }}`, merge with
  `npx playwright merge-reports`.

## GitLab CI

```yaml
e2e:
  image: mcr.microsoft.com/playwright:v1.47.0-jammy   # pin to the @playwright/test version
  stage: test
  script:
    - npm ci
    - npx playwright test
  variables:
    BASE_URL: $STAGING_URL
  artifacts:
    when: always
    paths:
      - playwright-report/
    reports:
      junit: playwright-results.xml
    expire_in: 30 days
```

The official Playwright image ships browsers + OS deps; its tag **must** match the
`@playwright/test` version in package.json or browsers mismatch at runtime.

## Artifacts

Config side (see config.md): `trace: 'on-first-retry'`, `screenshot: 'only-on-failure'`,
`video: 'retain-on-failure'`. On top of that, explicit captures at checkpoints of long
journeys:

```typescript
await page.screenshot({ path: 'artifacts/after-login.png' })
await page.screenshot({ path: 'artifacts/full.png', fullPage: true })
await page.locator('[data-testid="chart"]').screenshot({ path: 'artifacts/chart.png' })
```

Traces are the primary debugging artifact — DOM snapshots, network, console per action:

```bash
npx playwright show-trace playwright-report/data/<hash>.zip
```

Retention: 30 days for reports is a sane default; traces/videos are heavy — keep
failure-only capture unless actively hunting a flake.

## Report template

For humans, after a run worth reporting:

```markdown
# E2E Test Report

**Date:** YYYY-MM-DD HH:MM · **Duration:** Xm Ys · **Status:** PASSING / FAILING

## Summary
- Total: X | Passed: Y (Z%) | Failed: A | Flaky (passed on retry): B | Quarantined: C

## Failed
### <test name>
**File:** `tests/e2e/feature.spec.ts:45`
**Error:** <shortest decisive line>
**Trace:** <artifact link> · **Screenshot:** <artifact link>
**Diagnosis / next step:** <cause, not restatement of the error>

## Artifacts
- HTML report: playwright-report/index.html · JUnit: playwright-results.xml
```

Flaky count is a first-class metric — report it every run, rising trend = suite rotting.
