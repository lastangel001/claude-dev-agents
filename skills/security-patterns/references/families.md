# The Eight Families — questions to ask per family

A diff is walked family by family. Each hunk is read in its access model (the middleware stack,
the route table, the model's fillable list, the workflow it edits), not in isolation. Every
sample below is invented: `ledger-api` is a made-up service, every id and key a placeholder.

Before the first family: write the **trust boundaries** down. Where do requests enter (routes,
queue consumers, cron, webhooks)? Where is identity established (session middleware, token
guard, mTLS at the ingress)? Where is authorization decided (policy class, decorator, inline
check)? Where does data leave (responses, logs, outbound calls, files, metrics)? A finding later
names which boundary it crosses.

## 1. Authentication and authorization

- Is the auth check on every new route or handler, or on all but one? The health-endpoint pattern
  («this one is public») gets extended by accident; look at the group, not the route.
- Object-level authorization: does the handler check that `id` belongs to the caller or the
  caller's tenant, or only that the caller is logged in?
- Can a parameter the client controls escalate privilege: `role`, `is_admin`, `owner_id`,
  `tenant_id` accepted from the body or query into a create or update?
- Function-level authorization: is an admin action reachable by a non-admin who knows the URL
  (a route registered outside the admin group, an API verb the UI never shows)?
- Session fixation: is the session id rotated on login and on privilege change?
- Token lifetime and revocation: do tokens expire, can they be revoked, does logout invalidate
  the server side, do refresh tokens rotate?
- Password reset and OTP: single use, short expiry, bound to the account that requested it,
  rate-limited.

```php
// BAD — logged in, but any invoice id works
public function show(int $id): Invoice { return Invoice::findOrFail($id); }

// GOOD — scoped to the caller's tenant
public function show(Request $r, int $id): Invoice
{
    return Invoice::where('tenant_id', $r->user()->tenant_id)->findOrFail($id);
}
```

## 2. Input and uploads

- Is validation at the boundary (request → typed value, once) or scattered and skippable (one
  handler validates, the sibling does not)?
- Are length, range and format bounded, or only type? A 10 MB `name` field is valid UTF-8.
- Uploads: size limit; content type checked by content (magic bytes, image re-encode) and not by
  extension or the client's `Content-Type`; stored under a server-generated name; stored outside
  the web root or in a bucket with no execution; the client's filename never joins a path.
- Deserialisation of untrusted data: `unserialize`, `pickle.loads`, `yaml.load` without
  `SafeLoader`, XML parsers with external entities on, `Marshal.load`.
- Mass assignment: does raw input reach a model's `fill` / `create` / `update` / `**kwargs`
  without an allowlist?
- Numeric input used for money or quantity: negative amounts, zero, floats where integers were
  expected, overflow on a 32-bit column.

```python
# BAD — client-controlled filename joins the path, type by extension
dest = os.path.join(UPLOAD_DIR, file.filename)
if not file.filename.endswith(".png"): raise ValueError

# GOOD — content-checked, server-named, size-bounded
if len(data) > MAX_BYTES: raise TooLarge
img = Image.open(io.BytesIO(data)); img.verify()          # Pillow: a real image or an exception
if img.format not in {"PNG", "JPEG"}: raise BadType
dest = UPLOAD_DIR / f"{uuid4()}.{img.format.lower()}"
```

## 3. Data access

- Is every query parameterised, including the ORM's raw escape hatches: `DB::raw`, `whereRaw`,
  `->raw()`, `text()`, `cursor.execute(f"...")`, `$queryRaw` without the tagged template,
  `knex.raw` with interpolation?
- Multi-tenant filter: does every query on tenant data carry the tenant id, or does one path rely
  on the caller not guessing ids? A new repository method is the usual leak.
- Row-level rules: are scopes, policies or row-level security applied, or bypassed by a new
  method that goes around the model (a direct `DB::table`, a raw `SELECT` in a report)?
- Does a new column, serializer field or export expose something the API previously hid
  (password hash, internal notes, another user's email)?
- Sort and filter parameters: a column name from the request reaching `ORDER BY` or a dynamic
  `WHERE` is injection even with bound values elsewhere.
- Check-then-write on balance, stock, quota or a unique slug: is it inside a transaction with a
  row lock or an atomic conditional update, or can two requests both pass the check?

```ts
// BAD — column name from the request reaches ORDER BY
const rows = await db.raw(`SELECT * FROM invoices ORDER BY ${req.query.sort}`);

// GOOD — allowlist the column, bind the rest
const SORTABLE = new Set(['created_at', 'total']);
const col = SORTABLE.has(String(req.query.sort)) ? String(req.query.sort) : 'created_at';
const rows = await db('invoices').where({ tenant_id: tenantId }).orderBy(col);
```

## 4. File system

- Path traversal: is a client-supplied segment joined into a path without canonicalisation and a
  prefix check against the allowed root? `..`, absolute paths, URL-encoded slashes, `\` on
  Windows.
- Symlinks followed when reading, serving or extracting (archives especially: a zip entry can be
  a symlink or carry `../`).
- Temp files: predictable names, world-readable, left behind, created in a shared directory
  where another user can pre-create the name.
- Permissions on created files and directories; secrets written to disk in plaintext (a token
  cache, a debug dump, a `.env` written by a setup script).
- A file served to the client by name: is the `Content-Type` set by the server, is
  `Content-Disposition` forcing download for anything that could execute in the browser?

```php
// BAD — traversal: ?f=../../.env
$data = file_get_contents($dir . '/' . $_GET['f']);

// GOOD — canonicalise, then prefix-check
$root = realpath($dir);
$path = realpath($dir . '/' . $_GET['f']);
if ($path === false || !str_starts_with($path, $root . DIRECTORY_SEPARATOR)) { abort(404); }
```

## 5. External calls

- SSRF: is the host, scheme, port or path of an outbound request user-influenced (a webhook URL,
  an «import from URL» feature, an avatar fetch, a PDF renderer that loads images)? Are redirects
  followed into private ranges, link-local metadata endpoints, `file://`?
- Open redirect: a `next`, `return_to`, `redirect_uri` parameter used without a host allowlist or
  a relative-path rule.
- TLS verification disabled, or a timeout missing so a slow callee pins the worker; retries
  without a cap on a non-idempotent call.
- Secrets in URLs (query-string tokens end up in logs, referers and proxies) or in log lines of
  the request or response.
- Webhook receivers: is the signature verified with a constant-time compare, is replay bounded
  by a timestamp window?
- Data sent to the third party: does the payload carry more than the integration needs (a whole
  user record where an id was enough)?

```python
# BAD — user-supplied URL fetched as-is
resp = requests.get(payload["image_url"])

# GOOD — scheme and host allowlisted, private ranges blocked, no redirects, bounded
u = urlparse(payload["image_url"])
if u.scheme != "https" or u.hostname not in ALLOWED_IMAGE_HOSTS: raise BadUrl
if ipaddress.ip_address(socket.gethostbyname(u.hostname)).is_private: raise BadUrl
resp = requests.get(u.geturl(), timeout=5, allow_redirects=False, stream=True)
```

## 6. Crypto, tokens, sessions

- Home-made crypto, ECB mode, a static or reused IV, `rand()` / `random.random()` /
  `Math.random()` for anything security-relevant (tokens, ids that gate access, OTPs).
- Passwords hashed with MD5 or the SHA family, or compared in plaintext, instead of argon2id or
  bcrypt through the framework's hasher.
- Tokens predictable or short; reset tokens reusable or without expiry; a comparison that is not
  constant-time (`==` on a signature or an API key).
- JWT: `alg` taken from the token, `none` accepted, HS/RS key confusion (public key used as the
  HMAC secret), signature not verified on a read path, claims (`exp`, `aud`, `iss`) not checked.
- Cookie flags: `Secure`, `HttpOnly`, `SameSite`; session cookie scoped to a wider domain or
  path than needed; session not regenerated on login.
- Encryption at rest with the key next to the data (same config file, same bucket); no key
  rotation path.

```ts
// BAD — algorithm from the token, claims read before verification
const claims = jwt.decode(token) as Claims;

// GOOD — pinned algorithm and key, verified first, audience checked
const claims = jwt.verify(token, PUBLIC_KEY, { algorithms: ['RS256'], audience: 'ledger-api' }) as Claims;
```

## 7. Secrets and configuration

- Hard-coded secrets, credentials or private keys in the diff; secrets present in git history
  even if the diff removes them now (removal is not rotation).
- Secrets reaching CI logs (echoed env, `set -x`, verbose curl, a failing test that prints its
  config) or build artifacts (`.env` copied into an image, a bundle that inlines a server key).
- Debug mode, stack traces, profilers or verbose errors reachable in production configuration
  (`APP_DEBUG=true`, `DEBUG = True`, Django `ALLOWED_HOSTS = ['*']`, an admin UI on a public
  port).
- CORS: wildcard origin with credentials, origin reflected without an allowlist, `null` origin
  accepted.
- Default credentials, admin accounts seeded with a known password, services listening on all
  interfaces by default, a management port exposed by the compose file.
- Security headers the framework does not set by default: `Content-Security-Policy`,
  `Strict-Transport-Security`, `X-Content-Type-Options`.

## 8. Dependencies and CI

- Known advisories in the new or bumped dependencies, from the audit tool, not from memory
  (see `audit-tooling.md`).
- Lockfile missing or not updated with the manifest; version ranges where a pin is expected;
  a dependency pulled from a git URL or a tarball instead of the registry.
- A new dependency for one function: what does it pull in transitively, who maintains it, does
  the name look like a typo of a popular package.
- Actions or images referenced by a mutable tag instead of SHA or digest.
- `pull_request_target` (or a GitLab job with protected variables on a fork MR) combined with a
  checkout of the PR head; scripts from an untrusted PR running with secrets in scope.
- Workflow `permissions` wider than the job needs (`write-all`, `contents: write` on a lint job).
  Full detail in `ci-security.md`.
