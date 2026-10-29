# ORM Patterns

The ORM hides the SQL; the review has to find it again.

## Raw-SQL Escape Hatches, Parameterised

Every ORM has a door to raw SQL. The rule at the door: values through placeholders, identifiers
through an allow-list, never a string built from input.

```php
// Eloquent
// BAD: interpolated
Account::whereRaw("status = '$status'")->get();
// GOOD: bindings
Account::whereRaw('status = ? AND created_at > ?', [$status, $since])->get();
Account::selectRaw('count(*) as n, date_trunc(?, created_at) as d', ['day'])->groupBy('d')->get();
DB::select('SELECT id FROM accounts WHERE email = :email', ['email' => $email]);
// DB::raw() takes NO bindings — it is for expressions you wrote, not for data
$col = in_array($sort, ['created_at', 'total'], true) ? $sort : 'created_at';   // identifier allow-list
```

```php
// Doctrine
// DQL
$em->createQuery('SELECT a FROM App\Entity\Account a WHERE a.status = :status')->setParameter('status', $status);
// Native query with a result-set mapping
$rsm = new ResultSetMappingBuilder($em); $rsm->addRootEntityFromClassMetadata(Account::class, 'a');
$em->createNativeQuery('SELECT a.* FROM accounts a WHERE a.email = :email', $rsm)->setParameter('email', $email);
// DBAL
$conn->fetchAllAssociative('SELECT id FROM accounts WHERE status = ?', [$status]);
```

```python
# Django
Account.objects.raw("SELECT * FROM accounts WHERE status = %s", [status])       # list, not %-formatting
Account.objects.annotate(n=RawSQL("(SELECT count(*) FROM invoices WHERE account_id = accounts.id AND status = %s)", (status,)))
# .extra() is deprecated and takes params=[]; prefer expressions (F, Func, Subquery)
with connection.cursor() as cur:
    cur.execute("UPDATE accounts SET flag = %s WHERE id = %s", [flag, pk])
```

```python
# SQLAlchemy
# BAD
session.execute(text(f"SELECT id FROM accounts WHERE email = '{email}'"))
# GOOD
session.execute(text("SELECT id FROM accounts WHERE email = :email"), {"email": email})
```

The driver placeholder differs (`?`, `%s`, `:name`, `$1`); the ORM normalises it, the review checks
that no value ever enters the string before the driver sees it.

## Mass Assignment

```php
// Eloquent: BAD — any request field becomes a column, including is_admin
Account::create($request->all());
// GOOD: $fillable on the model AND validated input
protected $fillable = ['email', 'display_name'];
Account::create($request->validated());
// $guarded = [] (nothing guarded) is a finding unless the input is a DTO the code built itself
```

```python
# Django: forms / serializers with explicit fields
class AccountSerializer(serializers.ModelSerializer):
    class Meta:
        model = Account
        fields = ["email", "display_name"]          # never "__all__" on a model with privilege columns
# Account.objects.create(**request.data) is the same hole as $request->all()
```

Doctrine and SQLAlchemy have no mass assignment by default; the hole appears when someone writes
`setattr(obj, k, v) for k, v in payload.items()`.

## Transactions

```php
// Laravel: closure form retries deadlocks, commits on return, rolls back on throw
DB::transaction(function () use ($order) {
    $order->lines()->createMany(...);
    $order->update(['status' => 'placed']);
}, attempts: 3);

// Doctrine
$em->wrapInTransaction(function (EntityManagerInterface $em) use ($order): void {
    $em->persist($order);
    // flush happens at the end of the closure
});
```

```python
# Django: atomic as decorator or context manager; nested = savepoint
with transaction.atomic():
    order.save()
    OrderLine.objects.bulk_create(lines)
# transaction.on_commit(lambda: send_mail(...))  — side effects after commit, not inside

# SQLAlchemy 2.x: the Session is the unit of work
with Session(engine) as session, session.begin():
    session.add(order)
    # commit on exit, rollback on exception
```

Auto-commit mode per statement is the default in Eloquent and Django outside `atomic`; a sequence
of three saves that must succeed together is three transactions unless wrapped.

## Lazy Loading Traps

- Accessing a relation in a template or serializer loop (the N+1 shows up outside the query code).
- Doctrine proxies: `$order->getCustomer()->getName()` is a query per order; a serialiser that walks
  the object graph fires hundreds.
- SQLAlchemy: a lazy attribute touched after the session closed raises `DetachedInstanceError`;
  load what the caller needs with `selectinload` before returning the object.
- Eloquent `Model::preventLazyLoading()` in non-production; Django has no switch, count queries in tests.
- `->count()` / `.count()` on a relation inside a loop is a query each; `withCount()` / `annotate(Count())`.

## Unit-of-Work Pitfalls

### Doctrine

- Nothing hits the database until `$em->flush()`; `persist()` only schedules. A missing flush is a silent no-op.
- `flush()` writes **every** dirty entity in the identity map, not only the one you passed; a stray mutated object earlier in the request goes along.
- Loop of 50 000 inserts: `flush()` + `clear()` every 500, or memory grows per entity.
- After `clear()` every previously loaded entity is detached; re-fetch before touching relations.
- Bulk `UPDATE` through DQL/DBAL bypasses the identity map: entities already loaded keep the old values.

### SQLAlchemy

- `expire_on_commit=True` (default): after `commit()` every attribute reloads on next access, one query per object; when returning objects after commit, `Session(expire_on_commit=False)` or load again explicitly.
- Autoflush: a query inside a transaction flushes pending objects first; a half-built object fails the NOT NULL at an unexpected line.
- `session.merge()` vs `add()`: `merge` copies state onto the persistent instance, `add` on a detached instance errors.
- Bulk `session.execute(update(T).where(...))` does not update loaded instances (`synchronize_session="fetch"` to sync).

### Eloquent and Django

- `Model::update(...)` on a query builder bypasses model events, mutators and `updated_at` (Eloquent sets `updated_at`, Django `QuerySet.update()` does not touch `auto_now`).
- `save()` on a model loaded with `select` of some columns writes only the loaded dirty ones (Eloquent) / all fields (Django, use `update_fields=[...]`).
- `refresh_from_db()` / `->refresh()` after a raw update when the instance is reused.

## Model vs Schema Drift

The mapping says one thing, the database another: the error appears on the one query that touches the gap.

| Tool | CI check |
|---|---|
| Django | `python manage.py makemigrations --check --dry-run` (fails if a model change has no migration) |
| Doctrine | `php bin/console doctrine:schema:validate` (mapping valid, database in sync); `doctrine:migrations:status` for pending |
| Alembic | `alembic check` (no autogenerate diff pending); `alembic current` vs `heads` for unapplied |
| Laravel | no built-in diff; `php artisan migrate:status` for pending, a schema dump in tests (`schema:dump`) for drift |

Run the check against a database migrated from zero in CI, not against a developer's long-lived local one.
