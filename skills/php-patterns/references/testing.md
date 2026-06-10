# PHP Testing Patterns

## PHPUnit Skeleton

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

## Pest Equivalent

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

## Factories Over Hand-Written Arrays

```php
// Laravel
$user = User::factory()->create(['email' => 'a@b.io']);

// Symfony (Foundry)
$user = UserFactory::createOne(['email' => 'a@b.io']);
```

## Data Providers for Parametric Cases

```php
use PHPUnit\Framework\Attributes\DataProvider;

#[DataProvider('provideEmails')]   // PHPUnit 10+: attribute, not @dataProvider docblock
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

## HTTP / Feature Tests

```php
// Laravel
$response = $this->postJson('/api/v1/users', ['email' => 'a@b.io', 'name' => 'A']);
$response->assertCreated()->assertJsonPath('data.email', 'a@b.io');

// Symfony
$client = static::createClient();
$client->request('POST', '/api/v1/users', server: ['CONTENT_TYPE' => 'application/json'], content: json_encode($payload));
self::assertResponseStatusCodeSame(201);
```

## Inertia Assertions

If the project uses Inertia.js, prefer `assertInertia` with `AssertableInertia` over raw JSON assertions:

```php
$response->assertInertia(fn (AssertableInertia $page) =>
    $page->component('Users/Show')
         ->where('user.email', 'a@b.io')
);
```

## Coverage

```bash
vendor/bin/phpunit --coverage-text
vendor/bin/pest --coverage --min=80
```

Keep coverage thresholds in CI, not tribal knowledge.
