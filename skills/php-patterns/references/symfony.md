# Symfony Patterns

## Autowired Service

```php
// Auto-registered and autowired by default (services.yaml resource globs) — no attribute needed.
// Use #[Autowire] / #[AutoconfigureTag] only for non-default wiring.
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

## Messenger Handler

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

## Voter for Authorization

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
