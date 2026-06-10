# Laravel Patterns

## FormRequest → Command → Service → Resource

See [architecture.md](architecture.md) for the full controller/FormRequest/service chain. Never let raw `$request->all()` reach a model.

## Eloquent: Eager Load to Prevent N+1

```php
// Bad: N+1
$posts = Post::all();
foreach ($posts as $post) {
    echo $post->author->name; // separate query each time
}

// Good: eager load
$posts = Post::with('author')->get();
```

## Mass-Assignment Whitelist

```php
final class User extends Authenticatable
{
    protected $fillable = ['email', 'name'];   // explicit whitelist
    protected $hidden   = ['password', 'remember_token'];
    protected $casts    = ['email_verified_at' => 'datetime'];
}
```

## Jobs

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

## JSON Resources

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
