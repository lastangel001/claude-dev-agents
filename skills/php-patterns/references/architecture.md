# Architecture Patterns — DTOs, Services, Repositories, DI

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
