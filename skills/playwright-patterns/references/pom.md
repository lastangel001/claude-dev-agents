# Test Layout, Page Object Model, Fixtures

## File organization

```
tests/
├── e2e/
│   ├── auth/
│   │   ├── login.spec.ts
│   │   ├── logout.spec.ts
│   │   └── register.spec.ts
│   ├── features/
│   │   ├── browse.spec.ts
│   │   ├── search.spec.ts
│   │   └── create.spec.ts
│   └── api/
│       └── endpoints.spec.ts
├── pages/
│   ├── ItemsPage.ts
│   └── LoginPage.ts
├── fixtures/
│   ├── auth.ts
│   └── data.ts
└── playwright.config.ts
```

Specs group by feature area, not by page. One journey per test; happy path, edge case,
and error case as separate tests, not branches inside one.

## Page Object Model

Page object holds locators + actions. No assertions inside the page object — asserts
belong to the test, so failures read as behavior failures, not helper failures.

```typescript
import { Page, Locator } from '@playwright/test'

export class ItemsPage {
  readonly page: Page
  readonly searchInput: Locator
  readonly itemCards: Locator
  readonly createButton: Locator

  constructor(page: Page) {
    this.page = page
    this.searchInput = page.getByTestId('search-input')
    this.itemCards = page.getByTestId('item-card')
    this.createButton = page.getByTestId('create-btn')
  }

  async goto() {
    await this.page.goto('/items')
    await this.page.waitForLoadState('networkidle')
  }

  async search(query: string) {
    await this.searchInput.fill(query)
    await this.page.waitForResponse(resp => resp.url().includes('/api/search'))
  }
}
```

## Test structure

```typescript
import { test, expect } from '@playwright/test'
import { ItemsPage } from '../../pages/ItemsPage'

test.describe('Item Search', () => {
  let itemsPage: ItemsPage

  test.beforeEach(async ({ page }) => {
    itemsPage = new ItemsPage(page)
    await itemsPage.goto()
  })

  test('should search by keyword', async () => {
    await itemsPage.search('test')

    await expect(itemsPage.itemCards.first()).toContainText(/test/i)
    await expect(itemsPage.itemCards).not.toHaveCount(0)
  })

  test('should handle no results', async ({ page }) => {
    await itemsPage.search('xyznonexistent123')

    await expect(page.getByTestId('no-results')).toBeVisible()
    await expect(itemsPage.itemCards).toHaveCount(0)
  })
})
```

Prefer web-first assertions (`toHaveCount`, `toContainText`) over pulling values out and
comparing — they auto-retry until timeout, killing a whole class of races.

## Fixtures

Custom fixtures for anything more than one spec needs: authenticated context, seeded
data, a page object pre-navigated.

```typescript
// fixtures/auth.ts
import { test as base } from '@playwright/test'
import { ItemsPage } from '../pages/ItemsPage'

type Fixtures = {
  itemsPage: ItemsPage
}

export const test = base.extend<Fixtures>({
  // reuse a stored session — login runs once in globalSetup, not per test
  storageState: 'playwright/.auth/user.json',

  itemsPage: async ({ page }, use) => {
    const itemsPage = new ItemsPage(page)
    await itemsPage.goto()
    await use(itemsPage)
  },
})

export { expect } from '@playwright/test'
```

Auth via `globalSetup`: perform login once, `page.context().storageState({ path })`, then
every project/test reuses the JSON. Never a "login test" that other tests depend on.

## Test data

- Synthetic and self-owned: a test creates (via API or fixture) what it asserts on, and
  cleans up or uses unique keys (`test-${crypto.randomUUID()}`) so parallel runs don't collide.
- Seed through the API or DB fixtures, not through the UI — UI-driven setup is slow and
  couples every test to the setup flow's stability.
- Never real user data; never production credentials.
