# Performance, Layout, and Tooling

## OPcache

```ini
; php.ini for production
opcache.enable=1
opcache.memory_consumption=256
opcache.max_accelerated_files=20000
opcache.validate_timestamps=0    ; deploy must clear cache
opcache.preload=/var/www/preload.php
opcache.jit=tracing
opcache.jit_buffer_size=128M
```

## Profile Before Optimizing

- **Blackfire** for production-grade profiling.
- **Xdebug profile** (`xdebug.mode=profile`) for dev.
- **Tideways** for APM.

## N+1: Eager Load

```php
// Laravel
$posts = Post::with(['author', 'comments.author'])->paginate(20);

// Doctrine
$qb->select('p', 'a', 'c')
   ->from(Post::class, 'p')
   ->leftJoin('p.author', 'a')
   ->leftJoin('p.comments', 'c');
```

## Indexes

Add indexes for hot WHERE/ORDER BY columns. Verify with `EXPLAIN`.

## Caching

```php
$value = Cache::remember(
    key: "user:{$id}:profile",
    ttl: now()->addMinutes(15),
    callback: fn () => $this->profileService->load($id),
);
```

Cache invalidation: prefer event-driven (`UserUpdated` → forget `user:$id:*`) over TTL-only.

## Connection Pools

- DB: persistent connections (`PDO::ATTR_PERSISTENT => true` in the connection options) only when you understand the implications.
- HTTP: reuse Guzzle clients (handler stack), don't `new Client` per call.

## Project Layout (Framework-Agnostic Package)

```
project/
├── src/
│   ├── Domain/           # entities, value objects, domain services
│   ├── Application/      # use cases, commands, queries
│   ├── Infrastructure/   # repositories, HTTP clients, framework glue
│   └── Http/             # controllers, requests, resources
├── tests/
│   ├── Unit/
│   ├── Integration/
│   └── Feature/
├── composer.json
├── phpstan.neon
├── pint.json   (or .php-cs-fixer.php)
└── phpunit.xml (or Pest.php)
```

## Hooks (Claude Code)

Configure in `~/.claude/settings.json` PostToolUse hooks:

- **Pint / PHP-CS-Fixer**: auto-format edited `.php` files.
- **PHPStan / Psalm**: run static analysis after edits in typed codebases.
- **PHPUnit / Pest**: run targeted tests for touched files or modules.

Warn on edits that leave behind:

- `var_dump`, `dd`, `dump`, `die`, `exit` in non-test files.
- Raw SQL string concatenation.
- Disabled CSRF / session protections.
- New `eval`, `unserialize` on input, `shell_exec` calls.

## Tooling Baseline

`composer.json` (dev deps):

```json
{
  "require-dev": {
    "phpunit/phpunit": "^10.0",
    "phpstan/phpstan": "^2.0",
    "laravel/pint": "^1.0",
    "roave/security-advisories": "dev-latest"
  }
}
```

Run in CI: `pint --test && phpstan analyse && phpunit && composer audit`.
