# Configuration

## Baseline playwright.config.ts

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,        // stray .only fails CI instead of silently shrinking the suite
  retries: process.env.CI ? 2 : 0,     // retries in CI surface flakes as "flaky", locally they must fail loud
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'playwright-results.xml' }],
    ['json', { outputFile: 'playwright-results.json' }],
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
    // pin environment factors that cause "works on my machine" flakes:
    locale: 'en-US',
    timezoneId: 'UTC',
    viewport: { width: 1280, height: 720 },
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    // add the rest only when the matrix earns its runtime:
    // { name: 'firefox',       use: { ...devices['Desktop Firefox'] } },
    // { name: 'webkit',        use: { ...devices['Desktop Safari'] } },
    // { name: 'mobile-chrome', use: { ...devices['Pixel 5'] } },
  ],
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
})
```

## Decisions that matter

- **Chromium-first.** Start with one project; expand to firefox/webkit/mobile when a real
  cross-browser bug class justifies the ~3× runtime, or on release branches only.
- **Workers**: local unlimited, CI sized to the runner. Suite too slow with 1 CI worker →
  shard across runner jobs (`--shard=1/3`) before cranking workers on one box.
- **Timeouts are explicit.** Default global timeout hides slow regressions; explicit
  `actionTimeout`/`navigationTimeout` fail fast and point at the slow step.
- **`webServer` block** owns app startup — tests never assume something is already
  running, and `reuseExistingServer` keeps local iteration fast.
- **Pin locale/timezone/viewport.** Date formatting, i18n strings, and responsive
  breakpoints are top flake sources when the CI box differs from dev machines.
- **Env-specific config** via env vars (`BASE_URL`, credentials names), not per-env config
  files that drift.

## Bootstrap commands

```bash
npm i -D @playwright/test          # or pnpm add -D / yarn add -D per lockfile
npx playwright install             # browsers; add --with-deps on Linux/CI
npx playwright test                # run all
npx playwright test auth/login.spec.ts --headed
npx playwright test --debug        # inspector
npx playwright show-report
npx playwright codegen $BASE_URL   # locator scaffolding, not finished tests
```
