# Query Patterns

Why the endpoint spends 1 800 ms in the database and 12 ms in the code.

## N+1

One query for the list, then one per row for a relation. Visible in the query log as the same
statement with a different id, n times.

```python
# BAD (Django): 1 + n queries
for order in Order.objects.filter(status="open"):
    print(order.customer.name)          # SELECT ... FROM customers WHERE id = ?  per order

# GOOD: FK / one-to-one → JOIN; reverse / many-to-many → second query with IN (...)
orders = Order.objects.filter(status="open").select_related("customer").prefetch_related("lines")
```

```python
# SQLAlchemy 2.x
stmt = select(Order).where(Order.status == "open").options(
    selectinload(Order.lines),            # SELECT ... WHERE order_id IN (...)
    joinedload(Order.customer),           # JOIN for to-one
)
```

```php
// Eloquent
$orders = Order::with(['customer', 'lines'])->where('status', 'open')->get();
// Model::preventLazyLoading(! app()->isProduction()) in a service provider turns the N+1 into an exception in dev
```

```php
// Doctrine: fetch join in DQL; lazy proxies are the default and the trap
$q = $em->createQuery('SELECT o, c, l FROM App\Entity\Order o JOIN o.customer c JOIN o.lines l WHERE o.status = :s');
```

Counting the queries in a test (`assertNumQueries`, `django_assert_num_queries`, Laravel
`DB::enableQueryLog()`, Doctrine's SQL logger) is the regression guard.

## Pagination: keyset over OFFSET

```sql
-- BAD: page 5000 reads and discards 100 000 rows; rows shift between pages under inserts
SELECT id, created_at FROM events ORDER BY created_at DESC LIMIT 20 OFFSET 99980;

-- GOOD: keyset on a unique, ordered tuple; the cursor is (created_at, id) of the last row seen
SELECT id, created_at FROM events
WHERE (created_at, id) < (:last_created_at, :last_id)
ORDER BY created_at DESC, id DESC
LIMIT 20;
-- Index: (created_at DESC, id DESC). MySQL < 8.0.16 / SQLite: expand the row comparison to
-- created_at < ? OR (created_at = ? AND id < ?)
```

OFFSET is fine for an admin screen with 50 pages. Public APIs and infinite scroll get a cursor.

## Reading EXPLAIN

```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ... ;      -- PostgreSQL: runs the query
EXPLAIN ANALYZE SELECT ... ;                  -- MySQL 8.0.18+
EXPLAIN QUERY PLAN SELECT ... ;               -- SQLite
```

What to look for:

| Sign | Meaning | Fix |
|---|---|---|
| `Seq Scan` / `type: ALL` / `SCAN TABLE` on a big table | no usable index | add one that matches the predicate; check the type cast (`WHERE id = '42'` on bigint can skip the index on MySQL) |
| `rows=10` estimated, `actual rows=2 000 000` | stale statistics or a correlated predicate | `ANALYZE t`; extended statistics (PG) ; rewrite the predicate |
| `Nested Loop` with a Seq Scan inside | N rows × full scan | index the inner side |
| `Sort` with `external merge` on disk | `work_mem` too small or missing index for `ORDER BY` | index covering the sort, or less data |
| `Filter: ... Rows Removed by Filter: 900 000` | index found rows, most discarded | composite index including the filtered column |
| `Hash Join` on two large sets for a point lookup | missing selective predicate | check the WHERE reaches the join |

Run it on production-sized data; the planner chooses a Seq Scan on 300 rows because it is right to.

## Isolation Levels

| Level | Prevents | Allows | Default on |
|---|---|---|---|
| Read uncommitted | nothing | dirty reads | — (PG treats it as read committed) |
| Read committed | dirty reads | non-repeatable reads, phantoms | PostgreSQL |
| Repeatable read | + non-repeatable reads (PG: + phantoms, snapshot) | write skew | MySQL InnoDB |
| Serializable | everything; aborts on conflict (`40001`), caller retries | — | SQLite (single writer) |

Read committed plus `SELECT ... FOR UPDATE` on the rows you are about to change covers most
business transactions. Serializable is the right tool for invariants across rows («no two
overlapping bookings»); the application must retry on serialization failure.

## Locks

### Lock ordering

```sql
-- BAD: two transfers lock accounts in opposite orders → deadlock
-- tx1: lock 7, lock 3     tx2: lock 3, lock 7

-- GOOD: always the same order
SELECT id, balance FROM accounts WHERE id IN (3, 7) ORDER BY id FOR UPDATE;
```

### Queue with SKIP LOCKED

```sql
-- One job per worker, no contention, crashed workers release the row on rollback
UPDATE jobs SET status = 'running', started_at = now()
WHERE id = (
  SELECT id FROM jobs WHERE status = 'queued'
  ORDER BY priority DESC, id
  LIMIT 1 FOR UPDATE SKIP LOCKED
) RETURNING *;
-- PG 9.5+, MySQL 8.0+, MariaDB 10.6+; SQLite: no row locks, use a status column and the single writer
```

### Short transactions

```python
# BAD: lock held during the HTTP call; one slow provider stalls every writer on that row
with transaction.atomic():
    order = Order.objects.select_for_update().get(pk=order_id)
    receipt = payment_gateway.charge(order.total)        # 2–30 s
    order.mark_paid(receipt)

# GOOD: external call outside; a state column makes the transition idempotent
receipt = payment_gateway.charge(order_id, amount)
with transaction.atomic():
    updated = Order.objects.filter(pk=order_id, status="pending").update(status="paid", receipt=receipt)
```

Set `idle_in_transaction_session_timeout` (PG) / `innodb_lock_wait_timeout` (MySQL) so a forgotten
transaction cannot hold a lock forever.

## Batching

```sql
-- BAD: 5 000 round trips
INSERT INTO readings (sensor_id, value) VALUES (1, 20.5);  -- × 5 000

-- GOOD: one multi-row statement per 500–1 000 rows; COPY (PG) / LOAD DATA (MySQL) for files
INSERT INTO readings (sensor_id, value) VALUES (1, 20.5), (1, 20.7), (2, 19.9), ... ;
```

ORMs: `bulk_create(objs, batch_size=1000)`, `Session.execute(insert(T), rows)`,
`Model::insert([...])`, Doctrine: flush every n entities and `$em->clear()`.

## Read Replicas and Replication Lag

- Writes go to the primary; reads that follow a write in the same request go to the primary too
  (read-your-writes). A replica is for lists, reports, search.
- Lag is seconds under load: a redirect after `INSERT` that lists from a replica shows the old list.
- Routing is explicit: Django `DATABASE_ROUTERS`, Laravel `read`/`write` connection config with
  `sticky => true`, SQLAlchemy a second engine, Doctrine `PrimaryReadReplicaConnection`.

## Per-engine Notes

### SQLite

- One writer at a time; a second writer gets `SQLITE_BUSY`. Set `PRAGMA busy_timeout = 5000` (ms) on every connection.
- `PRAGMA journal_mode = WAL` lets readers proceed during a write; one persistent setting per database file.
- No `FOR UPDATE`, no `SKIP LOCKED`; `BEGIN IMMEDIATE` takes the write lock up front and avoids a deadlocked upgrade.
- Keep transactions short in ms, not in rows; the whole database is the lock.

### MySQL / MariaDB

- InnoDB `REPEATABLE READ` uses gap and next-key locks: `UPDATE ... WHERE status = 'x'` on an unindexed column locks the whole range between rows, other inserts wait. Index the predicate or use `READ COMMITTED` for such sessions.
- `SELECT ... FOR UPDATE` without an index locks every scanned row.
- `LIMIT` without `ORDER BY` returns a different set per plan.
- Query cache is gone (8.0); do not design around it.

### PostgreSQL

- MVCC: an `UPDATE` writes a new row version; the old one is dead until vacuum. A table updated 50 times per row per day bloats; monitor `n_dead_tup`, make sure autovacuum keeps up (`autovacuum_vacuum_scale_factor` lower on hot tables).
- Long-running transactions (including an idle `BEGIN`) block vacuum from cleaning rows newer than their snapshot.
- `COUNT(*)` scans; for a dashboard number use an estimate (`pg_class.reltuples`) or a counter table.
- Prepared statements with a pooler in transaction mode (PgBouncer): named prepares break unless the pooler supports them (1.21+); use protocol-level unnamed prepares or `prepare_threshold=0`.
