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

## Core Principles

### 1. Strict Types Always

Every new file declares strict mode at the top.

```php
<?php

declare(strict_types=1);

namespace App\Domain\User;
```

### 2. Explicit Over Magic

Avoid global state, service-locator lookups, and untyped arrays for cross-boundary data.

```php
// Good: typed DI, explicit contract
public function __construct(
    private readonly UserRepository $users,
    private readonly Clock $clock,
) {}

// Bad: facade in domain code
class Service
{
    public function find(string $id): ?User
    {
        return \App\Models\User::find($id); // hidden static dep
    }
}
```

### 3. EAFP Where It Fits

PHP supports both, but domain failures should throw, not return `null`/`false` as hidden error channels.

```php
// Good: throw on missing resource
public function get(UserId $id): User
{
    $user = $this->repo->find($id);
    if ($user === null) {
        throw new UserNotFound($id);
    }
    return $user;
}

// Bad: hidden error channel
public function get(string $id): User|false { /* ... */ }
```

## Modern PHP 8.3+

### Constructor Property Promotion + Readonly

```php
final class Money
{
    public function __construct(
        public readonly int $amount,    // minor units
        public readonly Currency $currency,
    ) {
        if ($amount < 0) {
            throw new \InvalidArgumentException('Amount must be non-negative.');
        }
    }

    public function add(self $other): self
    {
        if (!$this->currency->equals($other->currency)) {
            throw new \DomainException('Currency mismatch.');
        }
        return new self($this->amount + $other->amount, $this->currency);
    }
}
```

### Readonly Classes (8.2+)

```php
final readonly class UserId
{
    public function __construct(public string $value)
    {
        if (!Uuid::isValid($value)) {
            throw new \InvalidArgumentException('Invalid UUID.');
        }
    }
}
```

### Backed Enums

```php
enum OrderStatus: string
{
    case Pending = 'pending';
    case Paid = 'paid';
    case Shipped = 'shipped';
    case Cancelled = 'cancelled';

    public function isTerminal(): bool
    {
        return match ($this) {
            self::Shipped, self::Cancelled => true,
            self::Pending, self::Paid => false,
        };
    }
}
```

### `match` Expressions

```php
$rate = match ($plan) {
    Plan::Free => 0.0,
    Plan::Pro, Plan::Team => 0.10,
    Plan::Enterprise => 0.20,
};
```

`match` is strict (`===`), exhaustive, returns a value — prefer over `switch` for new code.

### Named Arguments

```php
$user = new User(
    id: UserId::new(),
    email: $email,
    isActive: true,
    createdAt: $clock->now(),
);
```

### First-Class Callables

```php
$users = array_map($repo->find(...), $ids);
```

### Intersection and Union Types

```php
public function handle(Loggable&Serializable $event): void { /* ... */ }
public function find(string|UserId $id): ?User { /* ... */ }
```

### Fibers (8.1+)

```php
$fiber = new Fiber(function (): void {
    $value = Fiber::suspend('suspended');
    echo "Resumed with: $value\n";
});

$result = $fiber->start();    // 'suspended'
$fiber->resume('hello');      // prints "Resumed with: hello"
```

In practice you'll use Amp or ReactPHP rather than raw fibers.

## Type System Patterns

### Avoid `mixed` and Untyped Arrays in Public APIs

```php
// Bad
public function process(array $data): mixed { /* ... */ }

// Good
public function process(CreateOrderCommand $command): OrderId { /* ... */ }
```

### `Self` and Covariant Returns

```php
class QueryBuilder
{
    public function where(string $cond): static
    {
        $clone = clone $this;
        $clone->conds[] = $cond;
        return $clone;
    }
}
```

### Generics via PHPStan/Psalm

PHP has no runtime generics, but static analysers understand templates:

```php
/**
 * @template T of object
 * @param class-string<T> $class
 * @return T
 */
public function get(string $class): object { /* ... */ }
```

## Error Handling

### Specific Exception Hierarchy

```php
abstract class AppException extends \RuntimeException {}

final class ValidationFailed extends AppException {}
final class UserNotFound extends AppException {}
final class PaymentDeclined extends AppException
{
    public function __construct(public readonly string $reason)
    {
        parent::__construct("Payment declined: {$reason}");
    }
}
```

### Exception Chaining

```php
try {
    $payload = json_decode($body, true, flags: JSON_THROW_ON_ERROR);
} catch (\JsonException $e) {
    throw new InvalidPayload('Body is not valid JSON.', previous: $e);
}
```

### Never Swallow Errors

```php
// Bad
try { $this->risky(); } catch (\Throwable) { /* ignore */ }

// Good
try {
    $this->risky();
} catch (KnownRecoverable $e) {
    $this->logger->warning('recoverable failure', ['e' => $e]);
    $this->fallback();
}
```

## DTOs and Value Objects

Replace shape-heavy associative arrays with explicit types.

```php
final readonly class CreateUserCommand
{
    public function __construct(
        public string $email,
        public string $name,
        public ?string $referralCode = null,
    ) {}
}

final class UserService
{
    public function create(CreateUserCommand $cmd): UserId { /* ... */ }
}
```

Use value objects for **money, identifiers, date ranges, addresses, percentages, e-mail addresses** — anything with invariants.

## Service Layer and Boundaries

Keep controllers thin. Business logic lives in services.

```php
// Controller (Laravel) — transport only
final class CreateUserController
{
    public function __construct(private readonly UserService $users) {}

    public function __invoke(CreateUserRequest $request): JsonResource
    {
        $id = $this->users->create($request->toCommand());
        return new UserResource($this->users->get($id));
    }
}

// FormRequest — validation + DTO mapping
final class CreateUserRequest extends FormRequest
{
    public function rules(): array
    {
        return [
            'email' => ['required', 'email'],
            'name'  => ['required', 'string', 'max:120'],
        ];
    }

    public function toCommand(): CreateUserCommand
    {
        $data = $this->validated();
        return new CreateUserCommand(email: $data['email'], name: $data['name']);
    }
}
```

## Repository Pattern

Wrap persistence behind an interface so the rest of the code depends on a contract, not an ORM.

```php
interface UserRepository
{
    public function find(UserId $id): ?User;
    public function save(User $user): void;
}

final class EloquentUserRepository implements UserRepository
{
    public function find(UserId $id): ?User
    {
        $row = UserModel::find($id->value);
        return $row ? $this->hydrate($row) : null;
    }

    // ...
}
```

Bind in `AppServiceProvider`:

```php
$this->app->bind(UserRepository::class, EloquentUserRepository::class);
```

## Dependency Injection

- Depend on **interfaces or narrow contracts**, not framework globals.
- Pass collaborators through **constructor**, never via `app()` / `\Container::get()` inside methods.
- For Symfony: autowire by type; declare in `services.yaml` only when interface→implementation isn't 1:1.

## Attributes (8.0+)

```php
#[AsCommand(name: 'app:sync-users')]
final class SyncUsersCommand extends Command { /* ... */ }

#[Route('/users/{id}', methods: ['GET'])]
public function show(string $id): Response { /* ... */ }

#[AsEventListener(event: OrderPlaced::class)]
final class SendOrderConfirmation { /* ... */ }
```

## Laravel Patterns

### FormRequest → Command → Service → Resource

Already shown above. Never let raw `$request->all()` reach a model.

### Eloquent: Eager Load to Prevent N+1

```php
// Bad: N+1
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->author->name; // separate query each time
}

// Good: eager load
$posts = Post::with('author')->get();
```

### Mass-Assignment Whitelist

```php
final class User extends Authenticatable
{
    protected $fillable = ['email', 'name'];   // explicit whitelist
    protected $hidden   = ['password', 'remember_token'];
    protected $casts    = ['email_verified_at' => 'datetime'];
}
```

### Jobs

```php
final class SendInvoice implements ShouldQueue
{
    use Queueable;

    public int $tries = 5;
    public int $timeout = 30;
    public array $backoff = [10, 60, 300];

    public function __construct(public readonly InvoiceId $invoiceId) {}

    public function handle(InvoiceService $invoices, Mailer $mailer): void
    {
        $invoice = $invoices->get($this->invoiceId);
        $mailer->send($invoice);
    }
}
```

### JSON Resources

```php
final class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id'         => $this->id,
            'email'      => $this->email,
            'name'       => $this->name,
            'created_at' => $this->created_at->toIso8601String(),
        ];
    }
}
```

## Symfony Patterns

### Autowired Service with Attributes

```php
#[AsService]
final class OrderPlacer
{
    public function __construct(
        private OrderRepository $orders,
        private EventDispatcherInterface $events,
        private LoggerInterface $logger,
    ) {}

    public function place(PlaceOrderCommand $cmd): OrderId
    {
        // ...
        $this->events->dispatch(new OrderPlaced($id));
        return $id;
    }
}
```

### Messenger Handler

```php
#[AsMessageHandler]
final class SendOrderConfirmationHandler
{
    public function __construct(private Mailer $mailer) {}

    public function __invoke(SendOrderConfirmation $message): void
    {
        $this->mailer->send($message->orderId);
    }
}
```

### Voter for Authorization

```php
final class PostVoter extends Voter
{
    protected function supports(string $attribute, mixed $subject): bool
    {
        return in_array($attribute, ['POST_EDIT', 'POST_DELETE'], true)
            && $subject instanceof Post;
    }

    protected function voteOnAttribute(string $attr, mixed $subject, TokenInterface $token): bool
    {
        $user = $token->getUser();
        return $user instanceof User && $subject->ownerId === $user->id;
    }
}
```

## Security

### Input Validation at the Boundary

- Laravel: **FormRequest** (`rules()`, `authorize()`).
- Symfony: **Validator** with constraint attributes on DTOs, or Form component.
- Convert validated arrays into typed Commands/DTOs before reaching domain logic.

### SQL: Parameterized Queries Only

```php
// Bad
DB::select("SELECT * FROM users WHERE email = '{$email}'");

// Good
DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// Good (Eloquent)
User::where('email', $email)->first();
```

### Output Escaping

- Blade `{{ $x }}` auto-escapes. `{!! $x !!}` does not — sanitize with `Purifier` first.
- Twig `{{ x }}` auto-escapes. `{{ x|raw }}` does not — sanitize via `HtmlSanitizer`.
- Never `echo` user input directly into HTML.

### CSRF

- Laravel: `VerifyCsrfToken` middleware on web routes (default). Never disable globally.
- Symfony: Form component issues tokens automatically; for API routes use stateless tokens (JWT / Sanctum-equivalent).

### Passwords

```php
// Storing
$hash = password_hash($plain, PASSWORD_ARGON2ID);

// Verifying
if (!password_verify($plain, $hash)) {
    throw new InvalidCredentials();
}

// Rehashing on cost upgrades
if (password_needs_rehash($hash, PASSWORD_ARGON2ID)) {
    $newHash = password_hash($plain, PASSWORD_ARGON2ID);
    $this->users->updatePassword($user->id, $newHash);
}
```

### Tokens

```php
$token = bin2hex(random_bytes(32));    // cryptographically secure
// never: rand(), mt_rand(), uniqid()
```

### Secrets

- Loaded via `env()` in `config/*.php` (read-only at runtime), or via `Symfony\Component\Dotenv` / vault.
- Never commit `.env`. Add to `.gitignore`. Provide `.env.example`.
- Run `composer audit` in CI; add `roave/security-advisories` as dev dep to block vulnerable installs.

### File Uploads

```php
$request->validate([
    'avatar' => ['required', 'image', 'mimes:jpg,png,webp', 'max:2048'], // KB
]);
$path = $request->file('avatar')->storeAs(
    path: 'avatars',
    name: \Str::uuid().'.'.$request->file('avatar')->extension(),
    options: 'private',
);
```

### Never Use Dangerous Functions on User Input

- `eval`, `assert($string)`, `unserialize`, `include $path`, `system`/`exec`/`shell_exec` with interpolated input.

## Testing

### PHPUnit Skeleton

```php
final class MoneyTest extends TestCase
{
    public function test_add_same_currency(): void
    {
        $a = new Money(100, Currency::USD);
        $b = new Money(50, Currency::USD);

        $sum = $a->add($b);

        self::assertSame(150, $sum->amount);
    }

    public function test_add_mismatched_currency_throws(): void
    {
        $this->expectException(\DomainException::class);
        (new Money(100, Currency::USD))->add(new Money(50, Currency::EUR));
    }
}
```

### Pest Equivalent

```php
it('adds same currency', function (): void {
    $sum = (new Money(100, Currency::USD))->add(new Money(50, Currency::USD));
    expect($sum->amount)->toBe(150);
});

it('throws on mismatched currency', function (): void {
    (new Money(100, Currency::USD))->add(new Money(50, Currency::EUR));
})->throws(\DomainException::class);
```

Pick one framework; never mix in the same project.

### Factories Over Hand-Written Arrays

```php
// Laravel
$user = User::factory()->create(['email' => 'a@b.io']);

// Symfony (Foundry)
$user = UserFactory::createOne(['email' => 'a@b.io']);
```

### Data Providers for Parametric Cases

```php
/**
 * @dataProvider provideEmails
 */
public function test_valid_email(string $email, bool $expected): void
{
    self::assertSame($expected, EmailValidator::isValid($email));
}

public static function provideEmails(): array
{
    return [
        ['user@example.com', true],
        ['no-at-sign',       false],
        ['',                 false],
    ];
}
```

### HTTP / Feature Tests

```php
// Laravel
$response = $this->postJson('/api/v1/users', ['email' => 'a@b.io', 'name' => 'A']);
$response->assertCreated()->assertJsonPath('data.email', 'a@b.io');

// Symfony
$client = static::createClient();
$client->request('POST', '/api/v1/users', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode($payload));
self::assertResponseStatusCodeSame(201);
```

### Inertia Assertions

If the project uses Inertia.js, prefer `assertInertia` with `AssertableInertia` over raw JSON assertions:

```php
$response->assertInertia(fn (AssertableInertia $page) =>
    $page->component('Users/Show')
         ->where('user.email', 'a@b.io')
);
```

### Coverage

```bash
vendor/bin/phpunit --coverage-text
vendor/bin/pest --coverage --min=80
```

Keep coverage thresholds in CI, not tribal knowledge.

## Performance

### OPcache

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

### Profile Before Optimizing

- **Blackfire** for production-grade profiling.
- **Xdebug profile** (`xdebug.mode=profile`) for dev.
- **Tideways** for APM.

### N+1: Eager Load

```php
// Laravel
$posts = Post::with(['author', 'comments.author'])->paginate(20);

// Doctrine
$qb->select('p', 'a', 'c')
   ->from(Post::class, 'p')
   ->leftJoin('p.author', 'a')
   ->leftJoin('p.comments', 'c');
```

### Indexes

Add indexes for hot WHERE/ORDER BY columns. Verify with `EXPLAIN`.

### Caching

```php
$value = Cache::remember(
    key: "user:{$id}:profile",
    ttl: now()->addMinutes(15),
    callback: fn () => $this->profileService->load($id),
);
```

Cache invalidation: prefer event-driven (`UserUpdated` → forget `user:$id:*`) over TTL-only.

### Connection Pools

- DB: keep `pdo.persistent=true` only when you understand the implications.
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
    "phpstan/phpstan": "^1.10",
    "laravel/pint": "^1.0",
    "roave/security-advisories": "dev-latest"
  }
}
```

Run in CI: `pint --test && phpstan analyse && phpunit && composer audit`.

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
