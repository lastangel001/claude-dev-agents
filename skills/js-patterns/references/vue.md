# Vue Patterns

Vue 3 with `<script setup lang="ts">` unless the project says otherwise. Options API and Vue 2
sections at the end: match the codebase, do not migrate in a diff.

## Component Architecture

### SFC order

```vue
<script setup lang="ts">
// 1 imports (vue → ecosystem → aliases → relative)  2 props / emits / model / slots
// 3 composables  4 local state  5 computed  6 methods  7 watchers  8 lifecycle hooks
</script>
<template><!-- multiple roots are allowed; then forward $attrs explicitly --></template>
<style scoped></style>
```

- `PascalCase.vue` for components, `useCamelCase.ts` for composables, feature-first folders.
- Container components own fetching and store access; presentational components get props and emit.

### Props and emits, typed

```ts
interface Props { label: string; variant?: 'primary' | 'secondary'; items: Item[] }
const props = withDefaults(defineProps<Props>(), { variant: 'primary' })

const emit = defineEmits<{
  submit: []
  select: [id: string, index: number]
}>()
```

- Object/array defaults need a factory in runtime declarations: `default: () => []`.
- Never assign to a prop or mutate an object prop in place; emit and let the owner change it.
- Every emitted event is declared; an undeclared one lands on the root element as a fallthrough attr.
- `inheritAttrs: false` + `v-bind="$attrs"` when the root is not the element that should get them.
- Props carry a type that tells the truth about nullability (`string | null`, not `string` with
  a `null` default).

### `defineModel`

```ts
// BAD: hand-rolled two-way binding that mutates the prop
const props = defineProps<{ modelValue: string }>()
function onInput(v: string) { props.modelValue = v }         // runtime warning, parent unchanged

// GOOD (Vue 3.4+)
const model = defineModel<string>({ required: true })
const title = defineModel<string>('title')                   // v-model:title
```

### `provide` / `inject`

```ts
// keys.ts
export const ThemeKey: InjectionKey<Ref<Theme>> = Symbol('theme')
// provider
provide(ThemeKey, readonly(theme))
// consumer
const theme = inject(ThemeKey)       // Ref<Theme> | undefined — handle the undefined
```

Use for theme/config/plugin APIs passed through many layers; not as a replacement for props one
level down, and not for mutable shared state (that is a store).

### Contract smells (either API)

- `$refs` reaching into a child's internals where a prop or event is the contract.
- `$parent` / `$root` traversal: breaks on any structural change.
- Global registration (component, directive, plugin) for something used in one place.
- `defineExpose` of more than the intended public surface.

## Composables

```ts
// composables/useWindowSize.ts
export function useWindowSize() {
  const width = ref(window.innerWidth)
  const onResize = () => { width.value = window.innerWidth }
  window.addEventListener('resize', onResize, { passive: true })
  onScopeDispose(() => window.removeEventListener('resize', onResize))
  return { width: readonly(width) }
}
```

- Name starts with `use`; returns refs/computed, never unwrapped snapshots.
- Accept `MaybeRefOrGetter<T>` and read it with `toValue()` so callers can pass a ref, a getter
  or a plain value.
- Cleanup goes in `onScopeDispose` (works in components, stores and `effectScope`), or
  `onUnmounted` when the composable is component-only.
- No module-scope side effects: a timer or listener started at import time is shared by every
  instance and never stops.
- Composables replace mixins: explicit imports, no name collisions, no hidden `this`.

## Reactivity Rules

| Need | Use |
|---|---|
| Primitive, or an object you will replace wholesale | `ref()` |
| Group of fields mutated in place | `reactive()` |
| Large array/object replaced as a unit (table data, chart series) | `shallowRef()` — deep tracking of thousands of rows is wasted work |
| Pass a reactive object's fields around | `toRefs(state)` / `toRef(state, 'x')` |

```ts
// BAD: destructuring kills the link
const { count } = reactive({ count: 0 })        // plain number, never updates
const { items } = props                          // snapshot (Vue < 3.5)

// GOOD
const state = reactive({ count: 0 }); const { count } = toRefs(state)
const items = computed(() => props.items)        // or props.items at the use site
```

- Replacing a `reactive` object (`state = newState`) breaks every binding; use `Object.assign` or a
  `ref`.
- `.value` in script, no `.value` in template; a `ref` inside `reactive` auto-unwraps. A forgotten
  or doubled `.value` is the most common reactivity bug after destructuring.
- `computed` is pure: no state writes, no `await`, a return on every branch. Async derived data is
  a `ref` filled by a `watch` or an async composable.
- `watch(source, cb)` for explicit sources, lazy by default; `watchEffect` when the dependencies
  are whatever the callback reads. `watch(() => obj.field)` beats `watch(obj, cb, { deep: true })`
  when one field matters.
- `watch(() => myRef, …)` watches the ref object (never changes); write `watch(myRef, …)` or
  `() => myRef.value`.
- A watcher that writes what it watches is a feedback loop; `immediate: true` runs before data.
- `nextTick` after the state change, before the DOM read; awaiting it earlier reads the old DOM.

```ts
// Vue 3.5: cancel the previous run's work
watch(query, async (q) => {
  const ac = new AbortController()
  onWatcherCleanup(() => ac.abort())                 // must be called synchronously
  results.value = await search(q, { signal: ac.signal })
})
```

## Lifecycle Cleanup — SPAs live for hours

Everything started in `onMounted` / `setup` / a watcher is stopped in `onUnmounted` (or
`onScopeDispose`). The checklist:

- `addEventListener` on `window` / `document` / `body` → `removeEventListener` with the same
  reference, or one `AbortController` whose `signal` every listener shares. Listeners added inside
  `watch` or `onMounted` callbacks count.
- `setInterval` / `setTimeout` / `requestAnimationFrame` → `clear*` / `cancelAnimationFrame`.
- `IntersectionObserver` / `ResizeObserver` / `MutationObserver` → `disconnect()`.
- Chart, map, editor, grid, player instances (Chart.js, Highcharts, Leaflet, CodeMirror…) →
  `destroy()` / `dispose()` / `remove()`. They hold DOM nodes and listeners; a route that mounts one
  per visit without destroying it leaks every visit.
- WebSocket / EventSource → `close()`; store `$subscribe` / `$onAction` and event-bus handlers →
  call the returned stop / `off`.
- Components inside `<KeepAlive>` do setup in `onActivated` and teardown in `onDeactivated`,
  not only in `onMounted`.

```ts
onMounted(() => { chart = new Chart(canvas.value!, cfg) })
onUnmounted(() => { chart?.destroy(); chart = null })
```

## Pinia

```ts
export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([])
  const total = computed(() => items.value.reduce((s, i) => s + i.price * i.qty, 0))
  async function add(productId: string) {
    const item = await api.product(productId)        // errors propagate; the caller decides
    items.value.push({ ...item, qty: 1 })
  }
  return { items, total, add }
})

// component
const cart = useCartStore()
const { items, total } = storeToRefs(cart)            // refs stay reactive; actions come off `cart`
```

- Setup stores. State changes through actions (or a single `$patch`), never `cart.items.push()`
  from a component: devtools history and the search for "who changed this" both depend on it.
- Derived data is a getter/computed, not a second field that drifts.
- A store is not an event bus; cross-store cycles and a page store reaching into another page's
  store are design smells.
- Server data cached in a store needs an invalidation rule for the events that change it.
- Keep state serialisable (SSR hydration, devtools, persistence).

## Vue Router

```ts
const routes = [{
  path: '/users/:id',
  name: 'user-detail',
  component: () => import('@/pages/UserDetail.vue'),   // lazy chunk
  props: true,
  meta: { requiresAuth: true },
}] satisfies RouteRecordRaw[]

router.beforeEach((to) => {
  if (to.meta.requiresAuth && !useAuthStore().isLoggedIn)
    return { name: 'login', query: { redirect: to.fullPath } }   // never bare `false` with no way out
})

// params change while the component stays mounted
const id = computed(() => String(useRoute().params.id))
watch(id, load, { immediate: true })
```

Type `meta` with `declare module 'vue-router' { interface RouteMeta { requiresAuth?: boolean } }`.

## Template Patterns

- `v-if` tears down; `v-show` toggles `display`. Frequent toggles → `v-show`; rarely shown or
  expensive subtrees → `v-if`.
- `:key` on every `v-for`, stable and unique within the list. Index is acceptable only for a static,
  never-reordered list; sorted/filtered/spliced lists need an id. On `<template v-for>` the key
  goes on the `<template>`.
- `v-if` and `v-for` on one element: in Vue 3 `v-if` wins and cannot see the loop variable. Filter
  in a `computed` or nest a `<template v-for>`.
- `v-model` on a `computed` needs a setter, or input is silently dropped.
- `v-html` only with sanitised input (see browser.md §XSS-safe rendering); interpolation `{{ }}`
  escapes.
- `@submit.prevent` on a real `<form>`: Enter-to-submit, autofill and the accessibility tree come
  free.
- Vue 2 leftovers in a Vue 3 file (`.native`, filters, `$listeners`, `$children`) are bugs, not
  style.

## Performance

| Technique | When |
|---|---|
| `v-once` | Truly static content |
| `v-memo="[a, b]"` | Long lists whose rows change rarely; profile first, it adds comparison cost |
| `shallowRef` / `shallowReactive` | Big data replaced wholesale |
| Virtual list (`vue-virtual-scroller` or similar) / pagination | Hundreds of rows or more |
| `defineAsyncComponent(() => import(…))` | Heavy, rarely shown components (editors, charts) |
| `<KeepAlive :max="10">` | Cached tabs/views; always bounded |
| Throttle/debounce + `{ passive: true }` | `scroll` / `resize` / `mousemove` handlers |
| Subpath imports (`lodash-es/debounce`) | Avoid pulling a whole library into the chunk |

- A heavy library imported at module scope in a rarely visited view belongs behind a dynamic import.
- Expensive `computed` recomputed per keystroke: debounce the input or memoise the heavy step.
- Read layout (`offsetWidth`, `getBoundingClientRect`) before writing styles, not interleaved in a
  loop.
- Images get `width`/`height` (no CLS) and `loading="lazy"` below the fold.

## Vue 3.5 APIs

```ts
// reactive props destructure — defaults inline, still reactive
const { count = 0, msg = 'hello' } = defineProps<{ count?: number; msg?: string }>()
watch(() => count, cb)                      // a getter; `watch(count, cb)` is a compile error

const input = useTemplateRef<HTMLInputElement>('input')   // matches ref="input" in the template
const id = useId()                                        // SSR-stable id for label/for pairs
```

Also: `onWatcherCleanup` (above), `<Teleport defer>`, and
`defineAsyncComponent({ loader, hydrate: hydrateOnVisible() })` for lazy hydration.

## Options API (Vue 3)

Same rules in another syntax: `emits: [...]` declared, `props` with types and factory defaults,
no side effects in `computed`, cleanup in `unmounted`, `activated` / `deactivated` under
`<KeepAlive>`. In a codebase that is Options API, new components are Options API; "migrate to
`<script setup>`" is a ticket.

## Vue 2 — what differs

Vue 2 is EOL (2023-12-31): review for security and correctness, do not modernise in place.

| Vue 2 | Vue 3 equivalent / note |
|---|---|
| `Vue.set(obj, key, v)` / `this.$set` — adding a key to a reactive object is not tracked | Proxies track it; `Vue.set` is unneeded |
| `this.$delete`; `arr[i] = x` not tracked | Use `splice` in Vue 2 |
| `beforeDestroy` / `destroyed` | `beforeUnmount` / `unmounted` |
| `.sync` modifier, `update:prop` | `v-model:prop`, `defineModel` |
| No `emits` option | `emits` required for a declared contract |
| Mixins for reuse | Composables; mixins collide silently on names |
| Filters `{{ x \| fmt }}` | Methods / computed |
| `$listeners`, `.native`, `$children` | Removed; `$attrs` includes listeners |
| Event bus via `new Vue()` | `mitt` or a store; `$on` / `$off` removed |

Migration pitfalls: `v-if` / `v-for` precedence flipped; `key` on `<template v-for>` moved to the
template; `data` must be a function; `@hook:` lifecycle listeners became `@vue:`.

## Nuxt 3/4

- Auto-imports: `ref`, `computed`, `useFetch`, `useRoute`, `defineStore` come without import
  lines. Outside Nuxt, import explicitly.
- `useAsyncData(key, fn)` / `useFetch(url, { key })`: a stable key dedupes server and client
  requests; fetch in setup, not in `onMounted`, when the data should be server-rendered.
- `window` / `document` / `localStorage` only in `onMounted` or behind `import.meta.client`;
  universal composables guard them. Hydration mismatch sources: `Date.now()`, `Math.random()`,
  locale formatting that differs between server and browser.
- `<ClientOnly>` hides content from crawlers; do not wrap SEO-relevant markup.
- `definePageMeta({ middleware, layout })` is how a page opts into Nuxt features.

```ts
// server/api/users/[id].get.ts — validate every input
export default defineEventHandler(async (event) => {
  const { id } = await getValidatedRouterParams(event, z.object({ id: z.string().uuid() }).parse)
  return findUser(id)
})

// nuxt.config.ts — only `public` reaches the browser bundle
export default defineNuxtConfig({
  runtimeConfig: { apiSecret: '', public: { apiBase: '' } },   // NUXT_API_SECRET, NUXT_PUBLIC_API_BASE
})
```

`useRuntimeConfig().public.*` is shipped to every visitor; a secret there is public, as is any
server-only value read in a file that ends up in the client bundle.
