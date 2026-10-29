# Schema Patterns

What a table looks like when it is still readable after five years of changes.

## Types

| Use | PostgreSQL | MySQL / MariaDB | SQLite | Avoid |
|---|---|---|---|---|
| Id | `bigint GENERATED ALWAYS AS IDENTITY` | `BIGINT UNSIGNED AUTO_INCREMENT` | `INTEGER PRIMARY KEY` | `int`, `serial` on new code, random UUID v4 as clustered PK |
| Client-generated id | `uuid` filled with UUIDv7 | `BINARY(16)` with UUIDv7 | `TEXT` | UUID v4 in an InnoDB PK |
| Money | `numeric(19,4)` | `DECIMAL(19,4)` | `INTEGER` minor units | `float`, `double`, `real` |
| Instant | `timestamptz` | `DATETIME(6)` in UTC by convention | `TEXT` ISO-8601 UTC | `timestamp` (PG, no zone), MySQL `TIMESTAMP` beyond 2038 |
| Date only | `date` | `DATE` | `TEXT` `YYYY-MM-DD` | storing a date in a datetime column |
| Text | `text` | `VARCHAR(n)` with a real n, `TEXT` for long | `TEXT` | `varchar(255)` as a reflex |
| Flag | `boolean NOT NULL DEFAULT false` | `TINYINT(1)` / `BOOLEAN` | `INTEGER` 0/1 | `varchar('yes')`, nullable booleans with three states |
| Enum-like | `text` + `CHECK (status IN (...))` or a lookup table | same (`ENUM` makes every new value a DDL) | `TEXT` + `CHECK` | integer codes with meaning only in code |
| Semi-structured | `jsonb` | `JSON` | `TEXT` + `json_valid()` CHECK | JSON for fields that are filtered or joined on |

```sql
-- BAD: floats for money, int id, naive timestamp
CREATE TABLE invoices (id int PRIMARY KEY, total float, issued timestamp);

-- GOOD (PostgreSQL)
CREATE TABLE invoices (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   bigint NOT NULL REFERENCES tenants (id),
  total       numeric(19,4) NOT NULL CHECK (total >= 0),
  currency    char(3) NOT NULL,
  status      text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'paid', 'void')),
  issued_at   timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);
```

## Constraints

- **PK** on every table; a surrogate `bigint` unless the natural key is short, stable and never updated.
- **FK** with an explicit action: `ON DELETE RESTRICT` by default, `CASCADE` only for true
  parent-owns-child rows (order → order_lines), `SET NULL` for optional references. Index the FK column.
- **NOT NULL** wherever a null has no business meaning; a nullable column with `COALESCE` in every query is a design smell.
- **CHECK** for invariants the application cannot guarantee from two code paths: ranges, enum values, `start_at < end_at`.
- **UNIQUE** for every business identity (`(tenant_id, email)`, `(order_id, line_no)`); the application's «check then insert» is a race.

```sql
-- BAD: uniqueness checked in code only
if not repo.exists(email): repo.insert(email)

-- GOOD: the constraint is the check; handle the violation
ALTER TABLE accounts ADD CONSTRAINT accounts_tenant_email_key UNIQUE (tenant_id, email);
INSERT INTO accounts (...) ON CONFLICT (tenant_id, email) DO NOTHING;   -- PG / SQLite
INSERT ... ON DUPLICATE KEY UPDATE ...;                                  -- MySQL
```

## Naming

- `lower_snake_case` everywhere; no quoted mixed-case identifiers (PG folds, MySQL depends on the OS).
- Tables plural (`invoices`) or singular (`invoice`): pick one per project and never mix.
- Columns: `id`, `<entity>_id` for FKs, `*_at` for instants, `*_on` for dates, `is_*` / `has_*` for booleans.
- Indexes: `<table>_<cols>_idx`, unique: `<table>_<cols>_key`, FK: `<table>_<col>_fkey`; let the tool
  name them only if the names are stable across engines.

## Indexes

### Composite column order

```sql
-- Query: WHERE tenant_id = ? AND status = ? AND created_at > ? ORDER BY created_at
-- BAD: range column first — the equality predicates cannot narrow the scan
CREATE INDEX invoices_bad_idx ON invoices (created_at, tenant_id, status);

-- GOOD: equality columns first, the range column last; ORDER BY rides the same index
CREATE INDEX invoices_tenant_status_created_idx ON invoices (tenant_id, status, created_at);
```

An index on `(a, b, c)` serves `WHERE a = ?`, `WHERE a = ? AND b = ?`, `a = ? AND b = ? AND c > ?`;
it does not serve `WHERE b = ?` alone.

### Covering index

```sql
-- SELECT id, total FROM invoices WHERE tenant_id = ? AND status = 'issued'
CREATE INDEX invoices_tenant_status_cover_idx
  ON invoices (tenant_id, status) INCLUDE (id, total);   -- PG 11+; MySQL: add the columns to the key
```

### Partial index for soft deletes

```sql
CREATE INDEX invoices_tenant_live_idx ON invoices (tenant_id, created_at)
  WHERE deleted_at IS NULL;                               -- PG, SQLite; MySQL has no partial indexes
```

### Foreign-key indexes

```sql
-- Every FK column: joins, ON DELETE checks and «find children of X» all need it
CREATE INDEX invoice_lines_invoice_id_idx ON invoice_lines (invoice_id);
```

PostgreSQL finds the missing ones with a query on `pg_constraint` vs `pg_index`; MySQL creates
FK indexes automatically, PostgreSQL and SQLite do not.

### When not to index

Columns with 3 distinct values alone, columns never in a WHERE/JOIN/ORDER BY, and anything on a
table with more writes than reads. Each index is a write amplifier; drop the ones `pg_stat_user_indexes`
/ `sys.schema_unused_indexes` show at zero scans.

## Soft Delete vs Archive

| Need | Pattern |
|---|---|
| «Undo» inside a short window, audit of who deleted | `deleted_at timestamptz NULL`, partial index, every query filters it (a default scope in the ORM) |
| Rows must vanish from the hot table (size, GDPR, cost) | `INSERT INTO invoices_archive SELECT ... ; DELETE ...` in batches, or partition by month and detach |
| Both | soft delete first, a nightly job moves rows older than N days to the archive |

Soft delete leaks: a `UNIQUE (email)` blocks re-registration after a soft delete. Use
`UNIQUE (email) WHERE deleted_at IS NULL` (PG) or a `deleted_at`-aware unique with a generated column (MySQL).

## Multi-tenant Filters

- `tenant_id` is the first column of every composite index and every unique constraint on tenant data.
- The filter lives in one place (ORM global scope, repository base class, PG row-level security),
  not in each query; a reviewer checks the one place.
- Row-level security (PG): `CREATE POLICY ... USING (tenant_id = current_setting('app.tenant')::bigint)`;
  index `tenant_id`; set the setting per transaction, never per connection in a pool.

## Per-engine Notes

### PostgreSQL

- `GENERATED ALWAYS AS IDENTITY` over `serial` (standard SQL, no detached sequence permissions).
- UUIDv7 is time-ordered; stores in `uuid`, generated client-side or by `uuidv7()` (PG 18+), extension before that.
- `jsonb`, not `json`; GIN index for `@>` containment; a `jsonb` field that is filtered on every request wants a real column.
- `timestamptz` stores UTC and converts on the session's `TimeZone`; `timestamp` stores what it was given and means nothing.
- `text` and `varchar(n)` perform the same; `varchar(n)` is a constraint, use it only when n matters.
- `ALTER TABLE ... ADD COLUMN ... DEFAULT <constant>` is metadata-only since 11; a volatile default (`now()`) still rewrites.

### MySQL / MariaDB

- InnoDB clusters the table on the PK: a random UUID v4 PK scatters inserts across pages; `BIGINT AUTO_INCREMENT` or UUIDv7 in `BINARY(16)`.
- Every secondary index carries the PK: a wide PK makes every index wide.
- `utf8mb4` (and `utf8mb4_0900_ai_ci` on 8.0) always; `utf8` is three-byte and rejects emoji.
- `DATETIME` stores what it is given (no zone, works past 2038); `TIMESTAMP` converts via session zone and ends in 2038. Store UTC in `DATETIME(6)` by convention.
- No partial indexes; emulate with a generated column (`is_live AS (deleted_at IS NULL)`) and index it, or a functional index on 8.0.13+.
- Invisible indexes (8.0): `ALTER TABLE t ALTER INDEX i INVISIBLE` to test a drop before dropping.
- `ENUM` columns: every new value is an `ALTER TABLE`; a `CHECK` on 8.0.16+ or a lookup table instead.
- MariaDB diverges from MySQL 8 (no `utf8mb4_0900_*`, different JSON, different invisible-column syntax): say which one.

### SQLite

- Dynamic typing: `INSERT INTO t (price) VALUES ('abc')` succeeds in a `REAL` column. `CREATE TABLE ... STRICT` (3.37+) enforces types; use it on every new table.
- `INTEGER PRIMARY KEY` is the rowid, the fastest key; `INTEGER PRIMARY KEY AUTOINCREMENT` only when ids must never be reused.
- Foreign keys are off until `PRAGMA foreign_keys = ON` per connection; the ORM must set it.
- No `ALTER COLUMN`, no `DROP CONSTRAINT`; `DROP COLUMN` since 3.35 with limits; everything else is create-new-table, copy, drop, rename (see migrations.md).
- Booleans are integers, dates are text/int/real by convention; CHECK them.
- Partial indexes and expression indexes work; `WITHOUT ROWID` tables for small lookup tables with a natural key.
