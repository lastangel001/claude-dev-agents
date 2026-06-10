# PHP Security Patterns

## Input Validation at the Boundary

- Laravel: **FormRequest** (`rules()`, `authorize()`).
- Symfony: **Validator** with constraint attributes on DTOs, or Form component.
- Convert validated arrays into typed Commands/DTOs before reaching domain logic.

## SQL: Parameterized Queries Only

```php
// Bad
DB::select("SELECT * FROM users WHERE email = '{$email}'");

// Good
DB::select('SELECT * FROM users WHERE email = ?', [$email]);

// Good (Eloquent)
User::where('email', $email)->first();
```

## Output Escaping

- Blade `{{ $x }}` auto-escapes. `{!! $x !!}` does not — sanitize with `Purifier` first.
- Twig `{{ x }}` auto-escapes. `{{ x|raw }}` does not — sanitize via `HtmlSanitizer`.
- Never `echo` user input directly into HTML.

## CSRF

- Laravel: `VerifyCsrfToken` middleware on web routes (default). Never disable globally.
- Symfony: Form component issues tokens automatically; for API routes use stateless tokens (JWT / Sanctum-equivalent).

## Passwords

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

## Tokens

```php
$token = bin2hex(random_bytes(32));    // cryptographically secure
// never: rand(), mt_rand(), uniqid()
```

## Secrets

- Loaded via `env()` in `config/*.php` (read-only at runtime), or via `Symfony\Component\Dotenv` / vault.
- Never commit `.env`. Add to `.gitignore`. Provide `.env.example`.
- Run `composer audit` in CI; add `roave/security-advisories` as dev dep to block vulnerable installs.

## File Uploads

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

## Never Use Dangerous Functions on User Input

- `eval`, `assert($string)`, `unserialize`, `include $path`, `system`/`exec`/`shell_exec` with interpolated input.
