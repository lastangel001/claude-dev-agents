# Pattern → Severity → Fix

Severity words follow the shared table in `docs/AGENT-CONTRACT.md` (CRITICAL breaks now under
realistic use; HIGH breaks under conditions that will occur or a control is missing on a sensitive
path; MEDIUM defence in depth with a plausible path; LOW hygiene without a path). The column here
is the severity on an **internet-facing** service with an **anonymous or low-privilege** attacker;
deployment context moves it (see the end of this file). Every sample is invented.

## The table

| # | Pattern | Severity | Fix |
|---|---|---|---|
| 1 | String-concatenated query: `"... WHERE id = $id"`, `f"... {user_id}"`, `` `... ${id}` `` | CRITICAL | Parameterise; bind through the driver or ORM, never through the string |
| 2 | Shell command built from input (`exec("convert $file")`, `subprocess(..., shell=True)`, `exec(\`convert ${f}\`)`) | CRITICAL | Argument array without a shell; allowlist the executable |
| 3 | Password compared in plaintext or hashed with MD5/SHA-* | CRITICAL | argon2id or bcrypt via the framework hasher; constant-time compare |
| 4 | JWT `alg` read from the token, `none` accepted, verification skipped on a read path | CRITICAL | Pin the algorithm and key server-side; verify before reading claims |
| 5 | Secret, key or `.env` committed (`AWS_SECRET_ACCESS_KEY=...`, a private key block) | CRITICAL | Remove, move to a secret store, **rotate the credential**; history rewrite does not undo exposure |
| 6 | `pull_request_target` with checkout of the PR head, or untrusted PR scripts with secrets in scope | CRITICAL | Checkout base only, or split into an unprivileged job; secrets never in the PR-triggered job |
| 7 | Route or handler without an auth check where siblings have one | CRITICAL | Apply the middleware or guard at the group level, not per route |
| 8 | Balance, stock or quota check-then-write without a lock or transaction | CRITICAL | `SELECT ... FOR UPDATE` inside a transaction, or an atomic conditional update |
| 9 | Object id from the request used without an ownership check (IDOR) | HIGH | Scope the query by the caller (`where owner_id = :me`) or a policy check |
| 10 | `fetch(userUrl)`, `requests.get(url)`, `Http::get($url)` with a user-influenced host (SSRF) | HIGH | Allowlist hosts and schemes; resolve and block private ranges; do not follow redirects blindly |
| 11 | TLS verification off: `verify=False`, `CURLOPT_SSL_VERIFYPEER => false`, `rejectUnauthorized: false` | HIGH | Remove; pin the CA bundle if the callee's chain is the problem |
| 12 | Raw HTML with user data: `innerHTML`, `v-html`, `{!! !!}`, `\|safe`, `mark_safe`, `dangerouslySetInnerHTML` | HIGH | Escape by default; sanitise with an allowlist sanitiser when HTML is the feature |
| 13 | CORS `*` (or reflected origin) with credentials | HIGH | Explicit origin allowlist; no credentials on wildcard |
| 14 | No rate limit on login, password reset, OTP or signup | HIGH | Throttle per account and per IP; lock or back off after failures |
| 15 | Redirect to a `next`/`return_to` parameter without a host check | HIGH | Relative paths only, or compare the host against an allowlist |
| 16 | Path built from input: `open(base + name)`, `file_get_contents($dir . $_GET['f'])`, `path.join(root, req.query.p)` | HIGH | Canonicalise, then assert the result starts with the allowed root; reject `..` and absolute paths |
| 17 | Deserialisation of untrusted bytes: `unserialize`, `pickle.loads`, `yaml.load` without a safe loader | HIGH | JSON with a schema; `yaml.safe_load`; a signed envelope when native objects are required |
| 18 | Mass assignment: raw request body into `fill` / `create` / `update` / `**kwargs` | HIGH | Allowlist the fields at the boundary (`$request->validated()`, a Pydantic model, a DTO) |
| 19 | Column or table name from the request in `ORDER BY` / dynamic `WHERE` | HIGH | Allowlist the identifiers; bind the values |
| 20 | Token, password or full request body written to logs | MEDIUM | Redact at the logger; log ids and hashes, never the secret |
| 21 | GitHub Action or base image referenced by tag, not SHA or digest | MEDIUM | Pin to the commit SHA / image digest; let a bot propose bumps |
| 22 | Workflow `permissions` broader than the job uses | MEDIUM | Least privilege per job; `contents: read` as the default block |
| 23 | Debug mode or stack traces enabled in production configuration | MEDIUM | Off in prod config; errors to the log, generic message to the client |
| 24 | Session cookie without `Secure`/`HttpOnly`/`SameSite` | MEDIUM | Set all three in the framework's session config |
| 25 | Outbound call with no timeout | MEDIUM | Connect and read timeouts on every client; a bounded retry only on idempotent calls |
| 26 | Lockfile missing or out of step with the manifest | MEDIUM | Commit the lockfile; install with the frozen flag in CI (`--frozen-lockfile`, `--require-hashes`, `composer install` not `update`) |

## Samples

Three languages per shape where the shape differs; one where it does not.

### 1. Injection through the string

```php
// BAD
$rows = DB::select("SELECT * FROM invoices WHERE id = $id");
// GOOD
$rows = DB::select('SELECT * FROM invoices WHERE id = ? AND tenant_id = ?', [$id, $tenantId]);
```

```python
# BAD
cur.execute(f"SELECT * FROM invoices WHERE id = {invoice_id}")
# GOOD
cur.execute("SELECT * FROM invoices WHERE id = %s AND tenant_id = %s", (invoice_id, tenant_id))
```

```ts
// BAD
await prisma.$queryRawUnsafe(`SELECT * FROM invoices WHERE id = ${id}`);
// GOOD — tagged template binds the values
await prisma.$queryRaw`SELECT * FROM invoices WHERE id = ${id} AND tenant_id = ${tenantId}`;
```

### 2. Shell command

```php
// BAD
exec("convert {$upload} -resize 200x200 {$thumb}");
// GOOD
(new Process(['convert', $upload, '-resize', '200x200', $thumb]))->mustRun();
```

```python
# BAD
subprocess.run(f"convert {upload} -resize 200x200 {thumb}", shell=True)
# GOOD
subprocess.run(["convert", upload, "-resize", "200x200", thumb], check=True, timeout=30)
```

```ts
// BAD
exec(`convert ${upload} -resize 200x200 ${thumb}`);
// GOOD
await execFile('convert', [upload, '-resize', '200x200', thumb]);
```

### 3. Password hashing and comparison

```php
// BAD
if (md5($input) === $user->password_md5) { ... }
// GOOD
if (password_verify($input, $user->password_hash)) { ... }   // or Hash::check()
```

```python
# BAD
if hashlib.sha256(pw.encode()).hexdigest() == user.pw_sha: ...
# GOOD
from argon2 import PasswordHasher
PasswordHasher().verify(user.pw_hash, pw)          # raises on mismatch; Django: check_password()
```

```ts
// BAD
if (createHash('sha256').update(pw).digest('hex') === user.pwSha) { ... }
// GOOD
if (await argon2.verify(user.pwHash, pw)) { ... }
```

### 7. Missing guard at the group

```php
// BAD — one route escaped the group
Route::middleware('auth:sanctum')->group(fn () => Route::get('/invoices', ...));
Route::get('/invoices/{id}/export', [InvoiceController::class, 'export']);   // no middleware

// GOOD — the sibling lives in the group
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/invoices', ...);
    Route::get('/invoices/{id}/export', [InvoiceController::class, 'export']);
});
```

```python
# BAD — FastAPI route added without the dependency its siblings carry
@router.get("/invoices/{id}/export")
async def export(id: int): ...

# GOOD — dependency on the router, every route inherits it
router = APIRouter(dependencies=[Depends(current_user)])
```

### 8. Check-then-write on a balance

```python
# BAD — two concurrent requests both see balance >= amount
acct = session.get(Account, acct_id)
if acct.balance >= amount:
    acct.balance -= amount

# GOOD — row locked for the duration of the transaction
acct = session.execute(select(Account).where(Account.id == acct_id).with_for_update()).scalar_one()
if acct.balance < amount: raise Insufficient
acct.balance -= amount
# or one atomic statement: UPDATE accounts SET balance = balance - :a WHERE id = :id AND balance >= :a
```

### 9. IDOR

```ts
// BAD — any invoice id for any logged-in user
const inv = await repo.findOneBy({ id: req.params.id });
// GOOD — scoped to the caller
const inv = await repo.findOneBy({ id: req.params.id, ownerId: req.user.id });
```

### 10. SSRF

```php
// BAD
$body = Http::get($request->input('callback_url'))->body();
// GOOD
$url = $request->input('callback_url');
$host = parse_url($url, PHP_URL_HOST);
abort_unless(in_array($host, config('integrations.allowed_hosts'), true), 422);
$ip = gethostbyname($host);
abort_if(filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE) === false, 422);
$body = Http::timeout(5)->withoutRedirecting()->get($url)->body();
```

### 15. Open redirect

```python
# BAD
return redirect(request.args.get("next", "/"))
# GOOD — relative paths only
nxt = request.args.get("next", "/")
if not nxt.startswith("/") or nxt.startswith("//"): nxt = "/"
return redirect(nxt)
```

### 17. Deserialisation

```python
# BAD
cfg = yaml.load(body)            # arbitrary Python objects
obj = pickle.loads(cached)       # from a shared cache another service writes
# GOOD
cfg = yaml.safe_load(body)
obj = json.loads(cached); validate(obj, SCHEMA)
```

```php
// BAD
$state = unserialize($_COOKIE['state']);
// GOOD
$state = json_decode($_COOKIE['state'], true, 8, JSON_THROW_ON_ERROR);  // and validate the shape
```

### 18. Mass assignment

```php
// BAD
Invoice::create($request->all());               // role, owner_id, is_paid from the body
// GOOD
Invoice::create($request->validated());         // FormRequest rules name the allowed fields
```

```python
# BAD
Invoice(**request.json)
# GOOD
Invoice(**InvoiceIn.model_validate(request.json).model_dump())   # Pydantic names the fields
```

### 20. Secrets in logs

```ts
// BAD
logger.info('auth ok', { headers: req.headers });        // Authorization header in the log
// GOOD
logger.info('auth ok', { userId: user.id, requestId });
```

## How deployment context moves the word

| Finding | Internet-facing | Internal-only (evidence named) |
|---|---|---|
| Missing auth on an admin route | CRITICAL | HIGH |
| IDOR on a single-tenant internal tool | HIGH | MEDIUM |
| SSRF from a service with no network egress policy | HIGH | HIGH (metadata endpoints are internal) |
| Debug mode on | MEDIUM | LOW |
| Unpinned action in a repo with no secrets | MEDIUM | LOW |

The review names the context it assumed in its summary so the reader can correct it.
