# Migration Patterns

A migration is a deploy that cannot be rolled back by redeploying the old image.

## Safety Checklist

Before a migration ships:

- [ ] Engine and version named; every «instant» claim below checked against them
- [ ] No full-table lock on a large table (concurrent index, metadata-only default, online DDL)
- [ ] New columns nullable or with a constant default; `NOT NULL` added later as a separate step
- [ ] Index creation is concurrent / online and outside the transaction where the engine requires it
- [ ] Backfill is a separate migration or command, batched, resumable, with progress logging
- [ ] Nothing dropped that the currently deployed code still reads (two-deploy rule)
- [ ] Timed on a production-sized copy; the lock duration is known, not guessed
- [ ] The migration is a new file; nothing already deployed was edited
- [ ] Recovery plan written as the next forward migration, not as `down()`
- [ ] `statement_timeout` / `lock_timeout` set for the migration session so a blocked DDL fails fast instead of queueing every other query behind it

## Expand-Contract (rename, type change, split)

Never rename or retype a live column in one step. Five steps, each its own deploy:

```
1. EXPAND    migration: add new column (nullable / default)
2. DUAL-WRITE deploy: code writes old AND new, still reads old
3. BACKFILL  command: copy old → new in batches
4. SWITCH    deploy: code reads new, still writes both; verify counts match
5. CONTRACT  deploy: code stops touching old; next migration drops it
```

```sql
-- 1. expand (rename username → display_name, or change int → bigint)
ALTER TABLE accounts ADD COLUMN display_name text;
-- 3. backfill: see «Backfills» below
-- 5. contract, two deploys later
ALTER TABLE accounts DROP COLUMN username;
```

Type change on PostgreSQL with the same shape (`int` → `bigint`) rewrites the table under an
exclusive lock; the expand-contract path above with a trigger for the dual write is the zero-downtime version.

## Adding a Column

```sql
-- GOOD everywhere: nullable, no rewrite
ALTER TABLE accounts ADD COLUMN avatar_url text;

-- GOOD on PostgreSQL 11+: constant default is metadata-only
ALTER TABLE accounts ADD COLUMN is_active boolean NOT NULL DEFAULT true;
-- NOT metadata-only: DEFAULT now(), DEFAULT gen_random_uuid() — volatile → full rewrite

-- BAD on any engine: NOT NULL without default on a populated table
ALTER TABLE accounts ADD COLUMN role text NOT NULL;
```

Adding `NOT NULL` later on PostgreSQL without a full scan: `ADD CONSTRAINT ... CHECK (col IS NOT NULL) NOT VALID`,
then `VALIDATE CONSTRAINT` (share lock only), then `ALTER COLUMN ... SET NOT NULL` (uses the validated check, PG 12+).

| Engine | Add column with default | Notes |
|---|---|---|
| PostgreSQL 11+ | instant for constant defaults | volatile default rewrites |
| MySQL 8.0.12+ | `ALGORITHM=INSTANT` for append-at-end; 8.0.29+ any position | not for `AUTO_INCREMENT`, not with row format `COMPRESSED`; check `ALTER ... ALGORITHM=INSTANT` errors instead of assuming |
| MariaDB 10.3+ | instant add column | similar restrictions |
| SQLite | `ADD COLUMN` is metadata-only | no `NOT NULL` without a non-null default, no `UNIQUE`/`PRIMARY KEY`, default must be constant |

## Indexes on Live Tables

```sql
-- PostgreSQL: outside a transaction block; on failure leaves an INVALID index — drop and retry
CREATE INDEX CONCURRENTLY accounts_email_idx ON accounts (email);
DROP INDEX CONCURRENTLY accounts_old_idx;

-- MySQL 8 / MariaDB: online DDL, fails instead of falling back to a copy
ALTER TABLE accounts ADD INDEX accounts_email_idx (email), ALGORITHM=INPLACE, LOCK=NONE;

-- SQLite: CREATE INDEX holds the write lock for the build; run it off-peak, no concurrent variant
```

On MySQL tables of hundreds of millions of rows, or for changes `INPLACE` refuses (PK change,
charset change), use an external tool: `gh-ost` or `pt-online-schema-change`; both copy into a
shadow table and swap.

## Removing a Column in Two Deploys

```
Deploy 1: code no longer reads or writes the column (ORM model field removed, serializer updated).
          Django: SeparateDatabaseAndState so the model forgets the field without a DROP.
          Doctrine/SQLAlchemy: remove the mapping, generate no migration yet.
Deploy 2: migration drops the column.
```

Dropping while the old code is still serving requests (rolling deploy, cached ORM metadata) is an
outage: `column "x" does not exist` on every request from the old pods.

## Backfills

```sql
-- BAD: one statement, one transaction, one lock, no progress, hours on a big table
UPDATE accounts SET normalized_email = lower(email);

-- GOOD: batches by PK range, commit per batch, resumable from the last id
-- (driver loop, or a PL/pgSQL DO block with COMMIT inside the loop on PG 11+)
UPDATE accounts SET normalized_email = lower(email)
WHERE id > :last_id AND id <= :last_id + 5000 AND normalized_email IS NULL;
-- log: batch 1 234 / 16 000, last_id = 6 170 000, 0.8 s
```

Rules:
- Batch size 1 000–10 000; measure, the right number is «under a second per batch».
- Range on the PK, not `LIMIT` with an unindexed `WHERE` (each batch rescans the already-done rows).
- Separate file from the schema change; on Laravel and Doctrine a console command, not a migration.
- Idempotent (`WHERE new IS NULL`) and resumable (log the last id).
- A short sleep between batches on a replica-lagged setup.

## Forward-only Rollback

```
Shipped: 0043_add_discount_pct (adds column)   → found a bug in production
Wrong:   edit 0043, or `migrate down` on prod (other envs already ran it; data written since)
Right:   0044_drop_discount_pct, or 0044 that fixes the data — a new forward migration
```

`down()` stays for local iteration. Once a migration ran anywhere shared, it is immutable: a new
file or nothing.

## Testing on a Production-sized Copy

- A nightly anonymised restore or a `pg_dump --schema-only` plus a generated 10M-row fill.
- Run the migration with `\timing` on, record the longest lock (`pg_locks`, `SHOW PROCESSLIST`).
- Run the app's smoke test against the migrated copy with the **previous** release of the code: the dual-deploy window is where the outage lives.

## Per-tool Workflows

### Alembic (SQLAlchemy)

```bash
alembic revision --autogenerate -m "add accounts.display_name"   # diff models vs DB
alembic upgrade head
alembic check                                                     # CI: models and migrations agree
```

- Autogenerate misses: type changes without `compare_type=True`, server defaults without
  `compare_server_default=True`, renamed columns (seen as drop + add), indexes on some dialects,
  anything in `CHECK`. Read every generated file before committing.
- Concurrent index: `with op.get_context().autocommit_block(): op.create_index(..., postgresql_concurrently=True)`.
- SQLite: `with op.batch_alter_table("accounts") as b: b.alter_column(...)` rebuilds the table
  (create, copy, drop, rename), because SQLite has no `ALTER COLUMN`; set `render_as_batch=True` in `env.py`.
- Data: `op.execute(text("UPDATE ... WHERE id > :a AND id <= :b").bindparams(...))` or better, a script.

### Django

```bash
python manage.py makemigrations --check --dry-run   # CI: no missing migration
python manage.py migrate
python manage.py sqlmigrate app 0044                # read the SQL before trusting it
```

```python
class Migration(migrations.Migration):
    atomic = False                                   # required for concurrent index on PG
    dependencies = [("billing", "0043_add_display_name")]
    operations = [
        AddIndexConcurrently(model_name="account", index=models.Index(fields=["email"], name="account_email_idx")),
    ]
```

- `RunPython(forward, reverse)` with `migrations.RunPython.noop` as reverse when there is nothing
  to undo; use `apps.get_model()` in the function, never the live model import.
- `SeparateDatabaseAndState(state_operations=[RemoveField(...)], database_operations=[])` for the two-deploy column drop.
- `AddIndexConcurrently` / `RemoveIndexConcurrently` from `django.contrib.postgres.operations`.
- Backfills: a `RunPython` is fine for small tables; big ones go into a management command that
  batches by PK with `.iterator()` + `bulk_update(batch_size=...)`.

### Doctrine Migrations

```php
final class Version20260301120000 extends AbstractMigration
{
    public function isTransactional(): bool { return false; }   // for CREATE INDEX CONCURRENTLY
    public function up(Schema $schema): void
    {
        $this->addSql('CREATE INDEX CONCURRENTLY accounts_email_idx ON accounts (email)');
    }
    public function down(Schema $schema): void
    {
        $this->addSql('DROP INDEX CONCURRENTLY accounts_email_idx');
    }
}
```

- `doctrine:migrations:diff` generates from the mapping; read it, it also drops what it does not know.
- `doctrine:schema:validate` in CI: mapping and database agree.
- `addSql()` with the `$params` argument for values; never interpolate.
- Data backfills in a `Command`, batched with `$em->clear()` per batch, not in `up()`.

### Laravel

```php
return new class extends Migration {
    public function up(): void
    {
        Schema::table('accounts', function (Blueprint $t) {
            $t->string('display_name', 120)->nullable()->after('email');
        });
        DB::statement('CREATE INDEX CONCURRENTLY accounts_email_idx ON accounts (email)');
    }
    public function down(): void
    {
        DB::statement('DROP INDEX CONCURRENTLY IF EXISTS accounts_email_idx');
        Schema::table('accounts', fn (Blueprint $t) => $t->dropColumn('display_name'));
    }
};
```

- `->change()` needs `doctrine/dbal` before Laravel 11; on 11+ it is native but rewrites the whole
  column definition, so repeat every modifier (`nullable()`, `default()`), not just the changed one.
- `DB::statement` for anything the builder cannot express (concurrent index, `NOT VALID` constraint); mark the migration `public $withinTransaction = false;` on PG.
- Backfills: an Artisan command with `Model::query()->whereNull('x')->chunkById(2000, fn ($rows) => ...)`, never inside `up()`.
- `php artisan migrate --pretend` prints the SQL; read it for the engine you deploy on, the builder's output differs per driver.
