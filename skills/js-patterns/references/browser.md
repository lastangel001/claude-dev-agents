# Browser Patterns (framework-free and under Vue)

What the DOM does with your data, and what the tab looks like after eight hours.

## DOM and Events

### Delegation

```ts
// BAD: one listener per row, re-attached on every render
rows.forEach(r => r.addEventListener('click', onRow))

// GOOD: one listener on the container, resolve the target
list.addEventListener('click', (e) => {
  const row = (e.target as HTMLElement).closest<HTMLElement>('[data-id]')
  if (row) select(row.dataset.id!)
})
```

### `AbortController` for listeners and fetch

```ts
const ac = new AbortController()
window.addEventListener('resize', onResize, { signal: ac.signal, passive: true })
document.addEventListener('keydown', onKey, { signal: ac.signal })
const res = await fetch(url, { signal: ac.signal })
// teardown — one call removes every listener and cancels the request
ac.abort()
```

In Vue: `onUnmounted(() => ac.abort())`. `{ passive: true }` on `scroll` / `touch*` / `wheel`
handlers that never `preventDefault()`, or scrolling waits for your handler.

### Global scope hygiene (no framework)

- One module per feature, `type="module"` scripts, no globals except an explicit `window.app`
  namespace when a legacy page needs it.
- `DOMContentLoaded` once; `defer` on script tags instead of `window.onload` chains.
- Template literals into `innerHTML` are the framework-free XSS: see below.

## Leaks in Long-lived SPAs — the checklist

For every change that starts something, find where it stops:

| Started | Stopped by |
|---|---|
| `addEventListener` on `window` / `document` / `body` / a long-lived node | `removeEventListener` (same function reference) or `AbortController` |
| `setInterval`, `setTimeout`, `requestAnimationFrame` | `clearInterval`, `clearTimeout`, `cancelAnimationFrame` |
| `IntersectionObserver` / `ResizeObserver` / `MutationObserver` | `disconnect()` |
| Chart / map / editor / grid / player instance | `destroy()` / `dispose()` / `remove()` |
| `WebSocket` / `EventSource` | `close()` |
| Store subscription, event-bus handler | returned unsubscribe / `off` |
| Component inside `<KeepAlive>` | `onDeactivated`, not only `onUnmounted` |

Symptoms: detached DOM trees in a heap snapshot, handlers firing on a route that is gone,
`ResizeObserver loop` warnings, memory that climbs per navigation and never comes back.

## Request Layer

One client for the app; every call goes through it. The client, not each caller, owns:

```ts
export class ApiError extends Error {
  constructor(readonly status: number, readonly body: unknown, message: string) { super(message) }
}

export async function request<T>(path: string, init: RequestInit & { timeoutMs?: number } = {}): Promise<T> {
  const ac = new AbortController()
  const timer = setTimeout(() => ac.abort(new DOMException('timeout', 'TimeoutError')), init.timeoutMs ?? 15_000)
  if (init.signal) init.signal.addEventListener('abort', () => ac.abort(), { once: true })
  try {
    const res = await fetch(`${BASE}${path}`, { ...init, signal: ac.signal, credentials: 'same-origin' })
    const body: unknown = res.headers.get('content-type')?.includes('json') ? await res.json() : await res.text()
    if (!res.ok) throw new ApiError(res.status, body, `${init.method ?? 'GET'} ${path} → ${res.status}`)
    return body as T            // the caller validates the shape (typescript.md §Typing the Boundary)
  } finally {
    clearTimeout(timer)
  }
}
```

- `fetch` resolves on 4xx/5xx: `res.ok` is checked here, once. A wrapper that returns `{}` or
  `undefined` on failure turns every error into data the UI renders as empty.
- Non-JSON error bodies (an HTML 502 page) must not crash in `res.json()`.
- Abort is not failure: callers test `e.name === 'AbortError'` and stay silent; everything else
  reaches the UI as a typed error, never `catch {}` / `.catch(() => {})`.
- Retries only for idempotent calls (GET, PUT with full body, DELETE), with backoff and a cap;
  never a POST that creates something.
- Search / autocomplete / filter: abort the previous request or guard with a sequence number, or a
  slow earlier response overwrites the fast later one.
- Optimistic UI keeps the previous value and restores it in the `catch`.
- Fire-and-forget (analytics, prefetch) is marked `void track(...)` with the reason, not left as
  an unawaited promise by accident.

## Silent Failures — the five shapes

A failure the caller cannot see is worse than a crash: the UI shows stale or empty data as if it
were real, and nobody is paged. Every shape below is a finding with the input that reaches it.

```ts
// BAD — each line hides a failure
const items = await api.list().catch(() => []);          // empty list looks like "no items"
try { await save(form); } catch (e) { console.log(e); }  // logged, forgotten, user sees nothing
catch (e) { throw new Error('save failed'); }            // original error and stack gone
await fetch(url);                                        // no timeout, no status check
const p = refresh();                                     // promise never awaited: rejection lost

// GOOD
const items = await api.list();                          // let the request layer surface it
try { await save(form); } catch (e) { notify.error(toMessage(e)); report(e, { formId }); throw e; }
catch (e) { throw new Error('save failed', { cause: e }); }
await fetch(url, { signal: AbortSignal.timeout(10_000) }).then(assertOk);
await refresh();                                         // or void refresh().catch(report)
```

1. **Fallback that hides the failure** — `.catch(() => [])`, `?? defaultValue` on a failed call,
   a store that keeps the previous state and clears the error. Show the error state instead.
2. **Log-and-forget** — a catch that logs without identifiers and continues as if nothing
   happened. Log with context, surface to the user, rethrow or return an explicit error result.
3. **Lost cause** — `throw new Error('x')` without `{ cause }`; the stack and the original message
   are gone, and the investigator starts from zero.
4. **No timeout, no status check** — a request that can hang forever, or `res.json()` on a 500.
   One client with `AbortSignal.timeout` and an `assertOk` step (see Request Layer).
5. **Unawaited promise** — `refresh()` without `await` or `.catch`; the rejection is unhandled and
   the UI never learns. `await` it, or `void p.catch(report)` when fire-and-forget is intended.

## XSS-safe Rendering

```ts
// BAD: user text becomes markup
el.innerHTML = `<li>${comment.text}</li>`
el.insertAdjacentHTML('beforeend', row.title)

// GOOD: text stays text
const li = document.createElement('li'); li.textContent = comment.text; el.append(li)

// GOOD: rich text through a sanitiser, at the render site, with the reason recorded
import DOMPurify from 'dompurify'
el.innerHTML = DOMPurify.sanitize(post.html, { USE_PROFILES: { html: true } })
```

- Sinks: `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`, `v-html`, `eval`,
  `new Function`, `setTimeout('string')`. Trace the value to its source; if it can carry user text
  it is XSS.
- URL sinks: `href`, `src`, `window.open`, `location.assign`, `iframe.src` built from data need a
  scheme allowlist (`http:`, `https:`, `mailto:`); `javascript:` and `data:text/html` execute.
- `target="_blank"` on links to user-supplied hosts needs `rel="noopener noreferrer"`.
- `postMessage`: check `event.origin` against an allowlist on receive; never `'*'` as the target
  origin for anything non-public.
- User-supplied SVG and Markdown are HTML: sanitise the rendered output, not the input.
- A CSP (`default-src 'self'; script-src 'self'; object-src 'none'`) is the second line; it does
  not replace escaping.

Server-escaped markup rendered through `v-html` / `innerHTML` is a legitimate pattern (search
highlights, trusted CMS output); the comment at the sink says where the escaping happened.

## Storage and Secrets

- Everything in the bundle is public: `import.meta.env.VITE_*`, `process.env.*` inlined at build,
  hostnames, keys. A secret belongs on the server; the client gets a short-lived, scoped token.
- Session tokens live in `httpOnly; Secure; SameSite` cookies when the backend supports it; a
  token in `localStorage` turns any XSS into account takeover.
- `localStorage` / `sessionStorage` hold preferences and drafts, versioned
  (`{ v: 2, ...}`), read through a guard (it may be absent, full, or hold an old shape).
- `IndexedDB` for anything larger than a few KB or structured.

## Accessibility — the part that is code

- A click handler on a `div` / `span` needs `role="button"`, `tabindex="0"`, and `keydown` for
  Enter / Space; or use a `<button>`.
- Every input has a `<label for>` (or `aria-label`); icon-only buttons have an accessible name.
- Modal / dropdown: move focus in on open, trap Tab inside, close on `Esc`, restore focus to the
  opener on close; `aria-modal="true"` + `role="dialog"`.
- Custom controls mirror native semantics: `role`, `aria-expanded`, `aria-selected`,
  `aria-controls`, arrow-key navigation for lists and tabs.
- Dynamic status text goes into an `aria-live="polite"` region; errors tie to the field with
  `aria-describedby` and `aria-invalid`.
- Colour is never the only signal; informative images have `alt`, decorative ones `alt=""`.
- Respect `prefers-reduced-motion` for anything that animates on its own.
