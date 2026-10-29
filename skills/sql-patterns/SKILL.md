---
name: sql-patterns
description: Data-store patterns for builders and reviewers — schema design (types, constraints, indexes, soft delete, multi-tenant), query hygiene (N+1, cursor pagination, EXPLAIN, isolation, lock ordering, SKIP LOCKED), zero-downtime migrations (expand-contract, concurrent indexes, batched backfills, forward-only rollback) for PostgreSQL, MySQL/MariaDB and SQLite; ORM escape hatches and drift checks for Doctrine, Eloquent, Django ORM and SQLAlchemy/Alembic; one section each for MongoDB, Redis/Dragonfly, ClickHouse, Elasticsearch/OpenSearch. Activate when writing, reviewing or planning anything that touches a database, or on «миграция», «добавь индекс», «схема таблицы», «N+1», «медленный запрос», «бэкфилл», «ревью миграции», «MongoDB», «Redis», «ClickHouse», «Elasticsearch», «write a migration», «design the schema», «review this query», «zero-downtime migration».
---

# Data-store Patterns

Patterns for the part of the system that outlives every deploy: the data. Target engines:
**PostgreSQL, MySQL/MariaDB, SQLite**; ORMs: **Doctrine, Eloquent, Django ORM, SQLAlchemy +
Alembic**; one section each for **MongoDB, Redis/Dragonfly, ClickHouse, Elasticsearch/OpenSearch**.

## When to Activate

Activate this skill whenever the user (or an agent's task) involves:

- Writing or reviewing a migration, a schema, an index, a raw query or an ORM query
- A slow endpoint whose time is spent in the database (`N+1`, missing index, OFFSET on page 400)
- Planning a column rename, type change or backfill on a table that is live in production
- Choosing or modelling data in MongoDB, Redis/Dragonfly, ClickHouse, Elasticsearch/OpenSearch
- Trigger phrases: «миграция», «добавь индекс», «схема таблицы», «N+1», «медленный запрос»,
  «бэкфилл», «ревью миграции», «write a migration», «design the schema», «review this query»,
  «zero-downtime migration», «MongoDB», «Redis», «ClickHouse», «Elasticsearch»

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| Types, constraints, naming, index design, soft delete vs archive, multi-tenant filters, per-engine schema notes | [references/schema.md](references/schema.md) |
| N+1 per ORM, cursor pagination, reading EXPLAIN, isolation levels, lock ordering, queues, batching, replicas | [references/queries.md](references/queries.md) |
| Safety checklist, expand-contract, concurrent indexes, two-deploy drops, batched backfills, Alembic / Django / Doctrine / Laravel workflows | [references/migrations.md](references/migrations.md) |
| Raw-SQL escape hatches with parameters, mass assignment, transactions per ORM, lazy loading, unit-of-work traps, drift checks | [references/orm.md](references/orm.md) |
| MongoDB, Redis and Dragonfly, ClickHouse, Elasticsearch/OpenSearch | [references/nosql.md](references/nosql.md) |

## Core Principles

1. **Every change is a migration.** Nothing is altered by hand in production; the migration file is
   the audit trail and the only way the change reaches the next environment.
2. **Forward-only in production.** A rollback is a new forward migration. `down()` exists for local
   work; it is not the recovery plan.
3. **Schema and data migrations are separate files.** DDL in one, the backfill in another (or in a
   command), so a failed backfill does not leave half a schema change in one transaction.
4. **Test against production-sized data.** A migration that takes 40 ms on 200 rows can hold a lock
   for 20 minutes on 80 million. Time it on a copy before it ships.
5. **Index every foreign key.** The engine does not do it for you (PostgreSQL, SQLite); the join and
   the `ON DELETE` both scan without it.
6. **Short transactions; never a lock across an external call.** Open late, commit early; no HTTP,
   queue or mail call between `BEGIN` and `COMMIT`.
7. **Parameterise everything.** Placeholders for values, an allow-list for identifiers; string
   concatenation into SQL is a finding regardless of where the string came from.
8. **The engine decides; check its version.** «Adding a column with a default is instant» is true on
   PostgreSQL 11+, on MySQL 8.0 for some cases, and never on SQLite. Name the engine and version
   before promising a lock-free change.

## Quick Reference

| Need | Pattern |
|---|---|
| Primary key | `bigint` identity / auto-increment, or UUIDv7 when ids are generated client-side |
| Money | `numeric(19,4)` / `DECIMAL(19,4)`, or integer minor units; never float |
| Time | `timestamptz` (PG), `DATETIME` in UTC (MySQL), ISO-8601 text in UTC (SQLite) |
| Composite index | equality columns first, then the range column, then `INCLUDE` what the SELECT reads |
| Soft delete | `deleted_at timestamptz NULL` + partial index `WHERE deleted_at IS NULL` |
| Pagination | keyset: `WHERE (created_at, id) < (?, ?) ORDER BY created_at DESC, id DESC LIMIT n` |
| Queue | `SELECT … FOR UPDATE SKIP LOCKED LIMIT n` in a short transaction |
| Deadlock avoidance | lock rows in one order everywhere: `ORDER BY id FOR UPDATE` |
| New index on a live table | `CREATE INDEX CONCURRENTLY` (PG), `ALGORITHM=INPLACE, LOCK=NONE` (MySQL), rebuild (SQLite) |
| Rename / type change | expand → dual-write → backfill → switch reads → contract, each its own deploy |
| Backfill | batches of 1 000–10 000 by PK range, commit per batch, log progress, resumable |
| Drop a column | deploy code that no longer reads it, then the migration that drops it |
| ORM raw SQL | `text()` / `whereRaw()` / `.raw()` / native query with bound parameters only |
| Drift check in CI | `makemigrations --check`, `doctrine:schema:validate`, `alembic check` |

## Anti-Patterns to Avoid

The linter does not catch these; a reviewer must.

- `SELECT *` in production code: the row shape changes under the caller, and the covering index is lost.
- `int` ids: 2.1 billion arrives on a busy table; `bigint` from day one.
- `timestamp` without zone: the value means a different instant on every server.
- Random UUID v4 as a clustered primary key (MySQL InnoDB especially): page splits, cold cache, big secondary indexes.
- OFFSET pagination on a big table: page 5 000 reads and discards 100 000 rows.
- Unparameterised queries, including «safe» ones built from an enum: injection, plan-cache churn.
- `GRANT ALL` to the application user: the app can drop its own tables.
- `NOT NULL` added without a default on a big table: a full rewrite under a lock.
- Index built inline on a live table: writes blocked for the whole build.
- Backfill inside a schema migration: one giant transaction, no progress, no resume.
- Lazy loading inside a loop (the N+1): 1 query becomes 1 + n.
- A lock held while calling an external service: one slow API call stalls every writer.

__Remember__: the schema will outlive the code that created it, and the migration runs on a table
ten thousand times larger than the fixture. Name the engine, measure on a copy, ship in steps.

Migration and PostgreSQL sections distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) `database-migrations` and `postgres-patterns` (MIT); the `database-reviewer` anti-pattern list informed `schema.md`.
