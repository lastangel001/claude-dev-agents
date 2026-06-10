---
name: php-patterns
description: Idiomatic PHP 8.3+ patterns — PSR-12, strict types, enums, readonly DTOs, repository/service layers, Laravel/Symfony framework patterns, security (SQLi/XSS/CSRF/mass-assignment), PHPUnit/Pest testing, hooks for Pint/PHPStan. Activate when writing, reviewing, or refactoring PHP code, or working with composer.json / Laravel / Symfony projects.
---

# PHP Development Patterns (8.3+)

Idiomatic PHP patterns and best practices for building robust, secure, maintainable applications. Target: **PHP 8.3+** exclusively.

## When to Activate

Activate this skill whenever the user (or an agent's task) involves:

- Writing or refactoring PHP code
- Reviewing PHP diffs / pull requests
- Designing Laravel / Symfony services, controllers, jobs
- Modernizing legacy PHP (5.x / 7.x → 8.3)
- Trigger phrases: "PHP", "Laravel", "Symfony", "Eloquent", "Doctrine", "PSR-12", "phpstan", "ревью PHP", "идиоматичный PHP"

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| 8.3 idioms: enums, readonly, `match`, attributes, fibers, types, error handling | [references/modern-php.md](references/modern-php.md) |
| DTOs/value objects, service layer, repository pattern, DI, attributes | [references/architecture.md](references/architecture.md) |
| Laravel: Eloquent N+1, `$fillable`, jobs, JSON resources | [references/laravel.md](references/laravel.md) |
| Symfony: autowiring, Messenger handlers, voters | [references/symfony.md](references/symfony.md) |
| SQLi/XSS/CSRF, passwords, tokens, secrets, uploads | [references/security.md](references/security.md) |
| PHPUnit/Pest, factories, data providers, HTTP/feature tests, coverage | [references/testing.md](references/testing.md) |
| OPcache, profiling, caching, pools, project layout, tooling/CI, hooks | [references/performance.md](references/performance.md) |

## Core Principles

1. **Strict types always.** `declare(strict_types=1);` at the top of every new file; typed signatures everywhere.
2. **Explicit over magic.** Typed constructor DI, no facades/service-locator in domain code, no untyped arrays across boundaries — use readonly DTOs.
3. **Throw, don't leak `null`/`false`.** Domain failures raise specific exceptions; never swallow with empty `catch (\Throwable)`.

## Quick Reference: PHP Idioms

| Idiom | Description |
|-------|-------------|
| `declare(strict_types=1);` | First line of every PHP file |
| Readonly DTO | Immutable command/response payloads |
| Backed enum | Type-safe taxonomy with methods |
| `match` | Strict, exhaustive, returns value |
| Constructor promotion | Eliminate boilerplate `__construct` |
| Named arguments | Self-documenting call sites |
| Attributes | Metadata for routing, DI, validation |
| FormRequest / Validator | Validate at the boundary |
| Repository interface | Decouple domain from ORM |
| `JsonResource` / DTO out | Never return ORM models to clients |
| `with()` / `JOIN FETCH` | Kill N+1 |
| `password_hash(ARGON2ID)` | Password storage |
| `random_bytes` | Cryptographic randomness |
| `Cache::remember` | Memoize expensive reads |

## Anti-Patterns to Avoid

```php
// Bad: untyped public API
function process($data) { /* ... */ }

// Good: typed
function process(CreateOrderCommand $cmd): OrderId { /* ... */ }

// Bad: facade in domain code
class Service { public function run(): void { \Cache::put('k', 'v'); } }

// Good: inject
class Service {
    public function __construct(private CacheRepository $cache) {}
    public function run(): void { $this->cache->put('k', 'v'); }
}

// Bad: `==`
if ($status == 'paid') { /* ... */ }

// Good: enum + strict
if ($status === OrderStatus::Paid) { /* ... */ }

// Bad: mass-assignment
User::create($request->all());

// Good: validated DTO
User::create($request->validated());

// Bad: raw SQL
DB::select("SELECT * FROM users WHERE id = $id");

// Good: bindings
DB::select('SELECT * FROM users WHERE id = ?', [$id]);

// Bad: swallowed exception
try { $this->run(); } catch (\Throwable) {}

// Good: log + rethrow
try { $this->run(); } catch (Recoverable $e) {
    $this->logger->warning('recoverable', ['e' => $e]);
    throw $e;
}

// Bad: null as error
function find(string $id): User|false { /* ... */ }

// Good: throw
function find(UserId $id): User { /* throws UserNotFound */ }
```

__Remember__: Modern PHP rewards types, immutability, and explicit boundaries. When in doubt, prefer clarity over cleverness — and let PHPStan / Psalm catch the rest.
