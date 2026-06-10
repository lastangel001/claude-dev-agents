# Modern PHP 8.3+ Language Features

## Constructor Property Promotion + Readonly

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

## Readonly Classes (8.2+)

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

## Backed Enums

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

## `match` Expressions

```php
$rate = match ($plan) {
    Plan::Free => 0.0,
    Plan::Pro, Plan::Team => 0.10,
    Plan::Enterprise => 0.20,
};
```

`match` is strict (`===`), exhaustive, returns a value — prefer over `switch` for new code.

## Named Arguments

```php
$user = new User(
    id: UserId::new(),
    email: $email,
    isActive: true,
    createdAt: $clock->now(),
);
```

## First-Class Callables

```php
$users = array_map($repo->find(...), $ids);
```

## Intersection and Union Types

```php
public function handle(Loggable&Serializable $event): void { /* ... */ }
public function find(string|UserId $id): ?User { /* ... */ }
```

## Fibers (8.1+)

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

### `static` and Covariant Returns

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
