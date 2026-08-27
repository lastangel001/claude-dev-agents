# Critical Flows — Financial, Destructive, Wallet/Web3

Flows that move money, mutate irreversibly, or touch external chains need extra guards:
they must never run against production, and their external dependencies are mocked or
sandboxed.

## Environment guards

```typescript
test('trade execution', async ({ page }) => {
  // Hard guard: destructive/financial tests never hit production
  test.skip(process.env.NODE_ENV === 'production', 'Never on production — real money')

  await page.goto('/markets/test-market')
  await page.locator('[data-testid="position-yes"]').click()
  await page.locator('[data-testid="trade-amount"]').fill('1.0')

  // Assert the preview BEFORE confirming — catches wrong-amount bugs pre-commit
  await expect(page.locator('[data-testid="trade-preview"]')).toContainText('1.0')

  await page.locator('[data-testid="confirm-trade"]').click()
  await page.waitForResponse(
    r => r.url().includes('/api/trade') && r.status() === 200,
    { timeout: 30_000 },
  )

  await expect(page.locator('[data-testid="trade-success"]')).toBeVisible()
})
```

Principles:
- **Preview-then-confirm assertion split**: assert the computed preview (amount, fee,
  recipient) before clicking confirm — the class of bug that matters most here is "right
  click, wrong payload".
- **Longer explicit timeouts** for settlement/blockchain waits — but still condition-based
  (`waitForResponse`), never sleeps.
- **Idempotent test data**: financial tests operate on dedicated test markets/accounts
  seeded per run; a rerun must not double-spend or accumulate state.
- **Verify the side effect through a second channel** when possible: after the UI reports
  success, hit the API/DB fixture to confirm the ledger entry exists exactly once.

## Wallet / Web3 mocking

Never drive a real wallet extension in E2E — mock the provider at init:

```typescript
test('wallet connection', async ({ page, context }) => {
  await context.addInitScript(() => {
    // Minimal EIP-1193 mock
    ;(window as any).ethereum = {
      isMetaMask: true,
      request: async ({ method }: { method: string }) => {
        if (method === 'eth_requestAccounts')
          return ['0x1234567890123456789012345678901234567890']
        if (method === 'eth_chainId') return '0x1'
      },
    }
  })

  await page.goto('/')
  await page.locator('[data-testid="connect-wallet"]').click()
  await expect(page.locator('[data-testid="wallet-address"]')).toContainText('0x1234')
})
```

- Extend the mock only as far as the flow needs (`eth_sendTransaction` returning a fake tx
  hash, `wallet_switchEthereumChain`, …) — a full provider emulation is a maintenance pit.
- Chain-dependent assertions (balances, confirmations) belong against a local devnet
  (anvil/hardhat) or a sandbox, wired via `BASE_URL`-style env config — not mainnet, not
  a shared testnet that other runs mutate.

## Destructive operations (delete/bulk/irreversible)

- Guard with env skip exactly like financial flows.
- The test creates the thing it deletes — never delete seed data other tests share.
- Assert both the success signal **and** the absence (list no longer contains it, direct
  GET returns 404) — deletion UIs love reporting success without deleting.
