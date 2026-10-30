---
name: security-patterns
description: Application-security patterns for builders and reviewers, language-agnostic with PHP, Python and TypeScript samples — the eight review families (authentication and authorization, input and uploads, data access, file system, external calls, crypto/tokens/sessions, secrets and configuration, dependencies and CI) with the questions to ask per family, a pattern → severity → fix catalog (injection, missing auth, IDOR, SSRF, open redirect, path traversal, unsafe deserialisation, weak hashing, JWT confusion, CORS, rate limits, secrets in logs), the false-positive list, read-only dependency audit commands per stack (composer audit, pip-audit, npm audit, govulncheck, cargo audit, bundle audit, gitleaks; never install), and CI security (workflow permissions, pull_request_target, pinning, secrets in logs). Activate when writing or reviewing code on a security trigger — auth, user input, uploads, queries, paths from input, outbound calls, crypto, sessions, secrets, env config, manifests, lockfiles, workflows — or on «безопасность», «уязвимость», «SQL-инъекция», «SSRF», «секрет в репозитории», «проверь зависимости», «ревью безопасности», «security review», «is this safe», «audit dependencies», «CVE», «OWASP».
---

# Security Patterns

Patterns for the access model of a change: who reaches the code, with what identity, carrying
what data, and what the code lets them do or learn that they should not. Stack-neutral; samples
in PHP, Python and TypeScript. Not a pentest guide, not a compliance checklist, no exploit payloads.

## When to Activate

Activate this skill whenever the user (or an agent's task) involves:

- Writing or reviewing code on a **security trigger**: authentication or authorization; user input
  or file uploads; database queries or query builders; file-system paths built from input; calls to
  external APIs; cryptography, tokens, sessions; secrets, credentials, environment configuration;
  dependency manifests, lockfiles or CI workflows
- A release review (the whole delta since the last tag) or a dependency bump
- Trigger phrases: «безопасность», «уязвимость», «SQL-инъекция», «SSRF», «секрет в репозитории»,
  «проверь зависимости», «ревью безопасности», «security review», «is this safe»,
  «audit dependencies», «CVE», «OWASP»

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| The questions per family: auth and authz, input and uploads, data access, file system, external calls, crypto/tokens/sessions, secrets and config, dependencies and CI | [references/families.md](references/families.md) |
| Pattern → severity → fix, with BAD/GOOD samples in PHP, Python and TypeScript | [references/catalog.md](references/catalog.md) |
| What is not a finding: example files, fixtures, public keys, checksums, framework defaults, internal-only services; the reachable-path rule | [references/false-positives.md](references/false-positives.md) |
| Read-only audit commands per stack, what each reports, how to say «not checked» | [references/audit-tooling.md](references/audit-tooling.md) |
| Workflow permissions, `pull_request_target`, fork safety, pinning, secrets in logs and artifacts, GitLab equivalents | [references/ci-security.md](references/ci-security.md) |

Language-local injection and XSS detail stays in `php-patterns`, `python-patterns` and
`js-patterns`; parameterised raw-SQL escape hatches per ORM live in `sql-patterns`
`references/orm.md`; pipeline structure beyond its security lives in `devops-patterns`.

## Core Principles

1. **Trust boundaries first.** Before reading a line, write down where requests enter, where
   identity is established, where authorization is decided and where data leaves. Every finding
   names the boundary it crosses.
2. **A finding needs a reachable path.** A concrete input or state, from a named entry point,
   that arrives at the defect. «Could be dangerous» without the path is an unverified assumption
   with the experiment that settles it, not a finding.
3. **Authorization is per object, not per session.** Logged in is not allowed; the handler proves
   the row belongs to the caller or the tenant on every read and write.
4. **Validate at the boundary, once.** Request → typed value at the edge; the rest of the code
   trusts the type, never re-parses the string.
5. **Parameterise everything that reaches an interpreter.** SQL, shell, LDAP, XPath, template
   engines: the data travels as a bound value, never inside the string.
6. **Outbound is input too.** A URL, host or redirect target the client influences is validated
   against an allowlist before the request leaves.
7. **Crypto comes from the framework.** Password hasher, token generator, constant-time compare,
   JWT library with a pinned algorithm; nothing home-made, nothing from `rand()`.
8. **Secrets by name, rotation on exposure.** A committed secret is rotated, not just removed;
   history rewrite does not undo exposure.
9. **Audit with the project's tools, read-only.** Advisory counts come from a tool that ran, never
   from memory; a tool that is absent is reported as «not checked», by name.
10. **Severity by consequence and context.** The shared table in `docs/AGENT-CONTRACT.md`
    decides the word; deployment context (internet-facing or internal, multi-tenant or not) moves
    it, and the review says which context it assumed.

## Quick Reference

| Need | Pattern |
|---|---|
| Query with user data | Bound parameters: `->where('id', $id)`, `text("... :id").bindparams(id=…)`, Prisma tagged `$queryRaw` (never string-built) |
| Object the caller may read | Scope the query by owner or tenant: `WHERE id = :id AND tenant_id = :tenant` |
| Shell command | Argument array, no shell: `new Process(['convert', $f])`, `subprocess.run([...])`, `execFile(bin, args)` |
| Path from input | `realpath` / `os.path.realpath` / `path.resolve`, then assert it starts with the allowed root |
| Outbound URL from input | Parse, allowlist scheme and host, resolve and block private ranges, do not follow redirects blindly |
| Redirect target | Relative path only, or host compared against an allowlist |
| Password | `password_hash` / `Hash::make`, `argon2`/`bcrypt` via the framework, constant-time compare |
| Random token | `random_bytes(32)`, `secrets.token_urlsafe(32)`, `crypto.randomBytes(32)`; never `rand`, `random`, `Math.random` |
| JWT | Pin `algorithms=[...]` and the key server-side; verify before reading any claim |
| Session cookie | `Secure`, `HttpOnly`, `SameSite=Lax` or `Strict`; rotate the id on login |
| Upload | Size limit, type by content, server-generated name, stored outside the web root |
| Secret in a diff | Remove, move to the store, **rotate**; say «rotate» to the user by credential name |
| Dependency check | `composer audit`, `pip-audit`, `npm audit --omit=dev`, `govulncheck ./...`, `cargo audit`, `bundle audit`; absent → «not checked» |
| GitHub workflow | `permissions: {contents: read}` at the top, widen per job; actions by SHA; never `pull_request_target` + PR-head checkout |

## Anti-Patterns to Avoid

The linter does not catch these; a reviewer must.

- A route added without the guard its siblings carry, or an auth middleware applied per route
  instead of at the group.
- An id from the request used after «is logged in» with no ownership or tenant check.
- `role`, `is_admin`, `owner_id` accepted from the request body into a model's fill or update.
- `verify=False`, `CURLOPT_SSL_VERIFYPEER => false`, `rejectUnauthorized: false` left in «for now».
- A token, password or whole request body in a log line, a URL query string or an error page.
- `yaml.load`, `pickle.loads`, `unserialize` on bytes that came from outside.
- A check-then-write on a balance, stock or quota outside a transaction or without a lock.
- `rand()` / `random.random()` / `Math.random()` for anything a user could guess at.
- A clean review table with no audit tool named: silence reads as «no CVEs».
- A finding at CRITICAL with no input that reaches it: the verifier marks it UNPROVEN and the
  author stops reading the next one.

__Remember__: a diff can be idiomatic, typed and tested and still hand an anonymous user another
tenant's rows. Ask of every line: which identity reaches it, and what is the worst thing it can
make the line do?
