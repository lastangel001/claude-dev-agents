# TypeScript Patterns (front-end)

The compiler proves what is inside the program. Everything that enters from outside (HTTP, route
params, storage, `postMessage`, third-party widgets) is `unknown` until checked.

## Strict Config

`"strict": true` plus the flags it does not include (full list in tooling.md):
`noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride`,
`noFallthroughCasesInSwitch`, `useUnknownInCatchVariables` (on under `strict`). A diff that
loosens `tsconfig` is a finding on its own.

## `unknown` over `any`

```ts
// BAD: `any` switches the checker off for everything downstream
function parse(raw: any) { return raw.user.name }

// GOOD: `unknown` forces a check at the one place it matters
function parse(raw: unknown): string {
  if (!isUserPayload(raw)) throw new ApiShapeError('user', raw)
  return raw.user.name
}
```

`catch (e)` is `unknown`: narrow with `e instanceof Error` before reading `.message`.

## Discriminated Unions and Narrowing

```ts
type LoadState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'ready'; data: T }
  | { status: 'error'; error: ApiError }

function render(s: LoadState<User>) {
  switch (s.status) {
    case 'ready': return s.data.name          // narrowed
    case 'error': return s.error.message
    default: return assertNever(s)            // `never` guard: a new variant fails to compile
  }
}
function assertNever(x: never): never { throw new Error(`unexpected ${JSON.stringify(x)}`) }
```

One `status` field beats three booleans (`loading`, `loaded`, `failed`) that can all be true.

## `satisfies`

```ts
// BAD: annotation widens, literal keys are lost
const routes: Record<string, string> = { home: '/', about: '/about' }
routes.hoem                                   // compiles

// GOOD: shape checked, literal type kept
const routes = { home: '/', about: '/about' } satisfies Record<string, string>
routes.hoem                                   // error
```

Use it for config objects, route tables, theme tokens, `defineNuxtConfig`-style literals.

## Typing the Boundary

### Props, emits, stores

```ts
defineProps<{ user: User; mode?: 'view' | 'edit' }>()
defineEmits<{ save: [user: User]; cancel: [] }>()
const store = defineStore('users', () => { const byId = ref<Record<string, User>>({}); … })
```

Vue infers the runtime validators from the type; keep the types in a shared `types/` module so
the store, the component and the API client agree on `User`.

### API responses: a schema or a guard, not a cast

```ts
// BAD: the cast is a promise; the server did not sign it
const user = (await res.json()) as User

// GOOD: zod at the boundary — one place, typed output
const UserSchema = z.object({ id: z.string(), name: z.string(), email: z.string().email() })
type User = z.infer<typeof UserSchema>
const user = UserSchema.parse(await res.json())       // throws ZodError with the path

// GOOD without a library: a hand-written guard
function isUser(x: unknown): x is User {
  return typeof x === 'object' && x !== null && typeof (x as User).id === 'string'
}
```

Route params (`useRoute().params.id` is `string | string[]`), `localStorage.getItem` (`string |
null`, then `JSON.parse` → `unknown`) and `event.data` from `postMessage` get the same treatment.

## Async with Typed Errors

```ts
class ApiError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) { super(message) }
}

try {
  await api.save(user)
} catch (e) {
  if (e instanceof ApiError && e.status === 409) return showConflict()
  if (e instanceof DOMException && e.name === 'AbortError') return         // cancelled, not failed
  throw e                                                                  // unknown → up
}
```

- Every `async` call is awaited or explicitly `void`ed with a comment saying why.
- `array.forEach(async …)` does not await; use `for…of` or `Promise.all`.
- Independent requests go through `Promise.all` / `Promise.allSettled`, not sequential awaits.
- Always `throw new Error(…)` (or a subclass), never a string or plain object.

## `Result`-style Returns

Where failure is expected and local (validation, parsing user input, optional lookups),
exceptions are the wrong tool: return a value the caller must inspect.

```ts
type Result<T, E = Error> = { ok: true; value: T } | { ok: false; error: E }

function parseQuantity(input: string): Result<number, 'empty' | 'nan' | 'negative'> {
  if (!input) return { ok: false, error: 'empty' }
  const n = Number(input)
  if (Number.isNaN(n)) return { ok: false, error: 'nan' }
  return n < 0 ? { ok: false, error: 'negative' } : { ok: true, value: n }
}
```

Network and programming errors still throw; `Result` is for the branches the UI will render.

## Utility Types to Prefer

| Need | Use |
|---|---|
| Subset of fields | `Pick<T, 'id' | 'name'>`, `Omit<T, 'password'>` |
| Form draft of a model | `Partial<T>`; `Required<T>` on submit |
| Immutable store snapshot | `Readonly<T>`, `ReadonlyArray<T>`, `as const` |
| Map keyed by an id union | `Record<UserId, User>` |
| Props of a component | `ComponentProps<typeof Button>` (vue-component-type-helpers) |
| Return type of a composable | `ReturnType<typeof useCart>` |
| Ref of a template element | `useTemplateRef<HTMLInputElement>('el')` |
| Branded ids | `type UserId = string & { readonly __brand: 'UserId' }` |

Prefer `interface` for object shapes that may be extended, `type` for unions and aliases;
`enum` rarely (a string-literal union is lighter and erasable).

## What `as` Hides

```ts
const el = document.querySelector('#app') as HTMLDivElement   // null at runtime → crash later
const el = document.querySelector<HTMLDivElement>('#app')     // HTMLDivElement | null, handled

const user = {} as User                                       // every field undefined, typed as set
const user: Partial<User> = {}                                // honest

value!                                                        // "trust me" — fine right after a guard
```

An `as` to an unrelated type (through `unknown`) silences the compiler, never the bug. The
acceptable uses: narrowing a DOM node after a tag check, `as const`, `satisfies`-shaped literals.
