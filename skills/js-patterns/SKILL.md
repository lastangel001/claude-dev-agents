---
name: js-patterns
description: Front-end JavaScript/TypeScript patterns — Vue 3 (Composition and Options API), Vue 2 differences, Nuxt 3/4, TypeScript at the boundary, framework-free browser code, Vitest + Vue Test Utils, ESLint flat config and vue-tsc. Covers what linters do not catch — XSS through raw HTML, listener/observer/chart leaks in long-lived SPAs, reactivity loss, store discipline, request-layer error handling. Activate when writing, reviewing or refactoring .vue / .ts / .js front-end code, or on «напиши компонент Vue», «ревью фронта», «Vue 3», «Nuxt», «TypeScript», «composable», «Pinia», «утечка слушателей», «XSS», «write a Vue component», «review this .vue», «front-end patterns».
---

# Front-end JavaScript / TypeScript Patterns

Patterns for browser code that lives for hours in one tab and renders strings typed by strangers.
Target: **Vue 3 + TypeScript** by default; Vue 2 and framework-free code where the project is there.
Not React, not Node servers.

## When to Activate

Activate this skill whenever the user (or an agent's task) involves:

- Writing or refactoring `.vue`, `.ts`, `.js` front-end code, composables, Pinia stores, Nuxt pages
- Reviewing a front-end diff (`js-reviewer` reads this skill for its checklist detail)
- Setting up ESLint / Prettier / `vue-tsc` / Vite / Vitest for a front-end project
- Trigger phrases: "Vue 3", "Nuxt", "TypeScript", "composable", "Pinia", "XSS", "write a Vue
  component", "review this .vue", "front-end patterns", "напиши компонент Vue", "ревью фронта",
  "утечка слушателей"

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| SFC structure, props/emits, composables, reactivity, lifecycle cleanup, Pinia, Router, templates, performance, Vue 3.5 APIs, Vue 2, Nuxt | [references/vue.md](references/vue.md) |
| Strict config, `unknown`, narrowing, `satisfies`, typing props/stores/API responses, typed errors, `Result`, what `as` hides | [references/typescript.md](references/typescript.md) |
| DOM/events, `AbortController`, SPA leak checklist, request layer, XSS-safe rendering, storage, accessibility in code | [references/browser.md](references/browser.md) |
| Vitest, Vue Test Utils, testing composables and stores, MSW, what not to test | [references/testing.md](references/testing.md) |
| ESLint flat config, Prettier, `vue-tsc`, Vite, `tsconfig`, scripts, `browserslist` | [references/tooling.md](references/tooling.md) |

## Core Principles

1. **Match the project's idiom.** Options API codebase gets Options API code; Vue 2 gets Vue 2
   semantics; a project with a request wrapper uses the wrapper. Migration is a ticket, not a diff.
2. **Text stays text.** User-derived strings reach the DOM through interpolation or `textContent`;
   `v-html` / `innerHTML` only for markup a sanitiser or the server already made safe.
3. **Everything you start, you stop.** Listener, timer, observer, chart instance, socket, store
   subscription: the teardown is written in the same change that creates it.
4. **Reactivity is a reference, not a value.** Never destructure `reactive()` or `props` into plain
   variables; `computed` is pure; `watch` is for side effects.
5. **Contracts are declared.** Typed `defineProps` / `defineEmits`, no prop mutation, store state
   changes only through actions.
6. **Failures surface.** The request layer checks `res.ok`, distinguishes abort from error, and hands
   the UI a typed error shape; `catch {}` is a bug.
7. **Types are checked at the boundary.** API responses, route params and storage are `unknown`
   until a guard or schema says otherwise; `as` is a promise the compiler cannot verify.
8. **Tests assert behaviour, with no fixed timeouts.** `await flushPromises()` and fake timers,
   never `setTimeout(…, 500)` in a test.

## Quick Reference: Idioms

| Idiom | Use |
|---|---|
| `<script setup lang="ts">` + `defineProps<T>()` / `defineEmits<T>()` | Typed component contract |
| `defineModel()` | Two-way binding without hand-written `update:modelValue` |
| `ref` for primitives/replaceable, `reactive` for grouped state, `shallowRef` for large data | Reactive state |
| `toRefs(props)` / `props.x` / Vue 3.5 reactive destructure | Reading props without losing reactivity |
| `watch(source, cb)` + `onWatcherCleanup` | Side effect with abort on re-run |
| `onScopeDispose` in composables, `onUnmounted` in components | Teardown |
| `defineStore('x', () => {...})` + `storeToRefs` | Pinia setup store, reactive reads |
| `() => import('./Page.vue')` | Lazy route chunk |
| `AbortController` for listeners and fetch | One `abort()` removes all |
| `unknown` + guard / `zod` schema | Typing data at the boundary |
| `satisfies` | Check shape, keep the literal type |
| `mount` + `await flushPromises()` | Component test with async work |

## Anti-Patterns to Avoid

The linter does not catch these; a reviewer must.

- Raw-HTML rendering of user data (`v-html`, `innerHTML`, `insertAdjacentHTML`) — XSS.
- Listeners, timers, observers, chart/map/editor instances, sockets never disposed — the tab leaks.
- Reactivity lost by destructuring a `reactive()` object or `props` into plain `const`s.
- `watch` with `deep: true` on a large object when one field is what changes.
- Async work or state mutation inside `computed`.
- Mutating props, or mutating an object prop in place.
- Store state written from a component instead of through an action.
- Request layer that returns `undefined` / `{}` on failure — the caller treats failure as data.
- Fixed timeouts in tests (`await new Promise(r => setTimeout(r, 500))`).
- Race on search/autocomplete: a slow earlier response overwrites a fast later one.

__Remember__: the tab will be open for eight hours and half the strings on screen were typed by
strangers. Clean up what you start, escape what you render, type what you receive.

Vue sections distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) `vue-patterns` (MIT).
