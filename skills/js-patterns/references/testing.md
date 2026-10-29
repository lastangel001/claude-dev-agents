# Testing Patterns (Vitest + Vue Test Utils)

Unit and component tests here; browser-level flows belong to the `playwright-patterns` skill.

## Vitest Setup

```ts
// vitest.config.ts
import { defineConfig, mergeConfig } from 'vitest/config'
import viteConfig from './vite.config'

export default mergeConfig(viteConfig, defineConfig({
  test: {
    environment: 'jsdom',             // or 'happy-dom'
    globals: false,                   // import { describe, it, expect } explicitly
    setupFiles: ['./test/setup.ts'],  // MSW server, global stubs
    coverage: { provider: 'v8', include: ['src/**'] },
  },
}))
```

Test files sit next to the unit (`Thing.spec.ts`) or in `__tests__/`; follow the repo.

## Vue Test Utils

### `mount` vs `shallowMount`

```ts
import { mount, flushPromises } from '@vue/test-utils'

const wrapper = mount(UserCard, {
  props: { user: { id: '1', name: 'Ada' } },
  global: { stubs: { RouterLink: true }, plugins: [createTestingPinia()] },
})
```

- `mount` renders children: the default. `shallowMount` stubs them: only when a child does heavy
  work (charts, editors) and the test is about the parent's wiring.
- Query by role or test id (`find('[data-testid="save"]')`), not by CSS class.

### Async: `flushPromises`, `nextTick`, fake timers — never a fixed wait

```ts
await wrapper.find('form').trigger('submit')
await flushPromises()                      // resolves pending fetches / awaited actions
expect(wrapper.text()).toContain('Saved')

vi.useFakeTimers()
await wrapper.find('input').setValue('ab')
vi.advanceTimersByTime(300)               // the debounce fires now, deterministically
await flushPromises()
```

```ts
// BAD: flaky and slow
await new Promise(r => setTimeout(r, 500))
```

### Emits and slots

```ts
await wrapper.find('button').trigger('click')
expect(wrapper.emitted('select')).toEqual([['1']])          // payload of the first emit

const w = mount(Card, { slots: { default: '<p data-testid="body">hi</p>', header: Header } })
expect(w.find('[data-testid="body"]').exists()).toBe(true)
```

`v-model`: `await wrapper.setProps({ modelValue: 'x' })` for input, `emitted('update:modelValue')`
for output.

## Composables

```ts
import { withSetup } from './withSetup'     // tiny helper: createApp + setup(() => composable)

const [result, app] = withSetup(() => useCounter(2))
result.increment()
expect(result.count.value).toBe(3)
app.unmount()                               // runs onScopeDispose — assert the listener is gone
```

A composable with no lifecycle hooks is a plain function: call it, inspect the refs. One with
`onMounted` / `onScopeDispose` needs a host component (the `withSetup` helper or `mount` of a
throwaway component). Assert the cleanup: spy on `removeEventListener` / `disconnect`.

## Pinia Stores

```ts
import { setActivePinia, createPinia } from 'pinia'
import { createTestingPinia } from '@pinia/testing'

beforeEach(() => setActivePinia(createPinia()))        // real store under test

it('adds an item', async () => {
  const cart = useCartStore()
  await cart.add('p1')
  expect(cart.items).toHaveLength(1)
})

// component test: stubbed actions, preset state
mount(Checkout, { global: { plugins: [createTestingPinia({
  initialState: { cart: { items: [item] } }, stubActions: true, createSpy: vi.fn,
})] } })
```

Test the store directly for logic; in component tests stub actions and assert they were called.

## Request Layer with MSW

```ts
// test/setup.ts
import { setupServer } from 'msw/node'
import { http, HttpResponse } from 'msw'

export const server = setupServer(
  http.get('/api/users/:id', ({ params }) => HttpResponse.json({ id: params.id, name: 'Ada' })),
)
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

// in a test: the failure path
server.use(http.get('/api/users/:id', () => HttpResponse.json({ code: 'gone' }, { status: 404 })))
```

Intercept at the network, not by mocking the request wrapper: the wrapper's `res.ok`, timeout and
non-JSON handling are what the test should exercise. Cover one 4xx, one 5xx, one HTML body, one
abort for every new endpoint family.

## What Not to Test

- Internal state and private methods: assert rendered output, emitted events, store state, calls
  to the request layer.
- The framework: that `v-if` hides an element, that Pinia updates a getter.
- Snapshot tests of whole components: they fail on every change and prove nothing specific.
- Styles and layout, except a class that carries behaviour (`is-disabled` on a control).

## E2E

User journeys across pages, auth, real backends: `playwright-patterns` (Page Object Model,
fixtures, flake diagnosis, no fixed timeouts there either).
