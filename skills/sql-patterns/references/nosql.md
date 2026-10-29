# NoSQL Patterns

Four engines, four different reasons to not be a relational database. Each gets one section:
what to model, what to never do, what to verify against the version in use.

## MongoDB

### Modelling: embed vs reference

| Embed when | Reference when |
|---|---|
| child is read with the parent every time (order → lines) | child is shared or queried alone (product → reviews) |
| bounded size (tens, not thousands) | unbounded growth (16 MB document limit, slow array updates) |
| child never updated independently | child has its own lifecycle |

```js
// BAD: unbounded array, every comment append rewrites the document
{ _id, title, comments: [ { user, text, at }, ... 40 000 ] }

// GOOD: reference from the many side; index it
posts:    { _id, title, comment_count }
comments: { _id, post_id, user_id, text, at }      // index { post_id: 1, at: -1 }
```

### Writes

- `updateOne` with operators (`$set`, `$inc`, `$push`) is atomic per document; read-modify-write of a whole document from the app is a lost-update race.
- `findOneAndUpdate` for «claim this job» semantics; `upsert: true` with a unique index for idempotent inserts.
- `writeConcern: { w: "majority" }` for anything that must survive a primary failover.

### Indexes

- Compound order follows ESR: Equality fields, then Sort field, then Range.
- Partial index: `{ partialFilterExpression: { deleted_at: null } }` for soft deletes, `{ status: "open" }` for a hot subset.
- Unique indexes enforce business identity; a `find` then `insert` is a race here too.
- `explain("executionStats")`: `COLLSCAN` on a big collection and `totalDocsExamined` ≫ `nReturned` are the two findings.
- Build indexes on a live replica set with the default (4.2+) non-blocking build; still measure on a copy.

### Schema evolution without migrations

```js
// Versioned documents, lazy migration on read, optional background sweep
{ _id, schema_v: 2, name: { first, last } }        // v1 had name: "First Last"
function readAccount(doc) {
  if (doc.schema_v === 1) { doc = migrateV1toV2(doc); collection.updateOne({ _id: doc._id, schema_v: 1 }, { $set: doc }); }
  return doc;
}
```

The reader handles every live version; a sweep job upgrades the rest at low priority. Schema
validation (`$jsonSchema`) in `validationLevel: "moderate"` guards new writes without rejecting old documents.

### Transactions

Multi-document transactions since 4.0 (replica set) / 4.2 (sharded). They cost: 60 s default
limit, write conflicts abort and must be retried (`withTransaction` does it), held locks on every
touched document. A design that needs them on every request wanted a relational database or an embedded model.

### Smells

- `$lookup` on every read path: the data should have been embedded, or this is a join workload.
- Pagination with `skip`: same O(n) as OFFSET; paginate by `_id` (ObjectId is time-ordered) or by an indexed sort key plus `_id`.
- `find({})` without projection: whole documents over the wire for a list of titles.
- Collection per tenant above a few hundred tenants: namespace and index memory grow per collection.

## Redis and Dragonfly

### Keys and TTL

- Namespaced keys with a stable layout: `app:session:{sid}`, `app:rate:{user_id}:{minute}`; the
  `{...}` hash tag keeps related keys on one cluster slot.
- TTL on everything cacheable: `SET k v EX 300`; a key without TTL is a leak waiting for `maxmemory`.
- `maxmemory-policy allkeys-lru` (or `volatile-lru`) chosen on purpose; the default `noeviction` returns errors when full.

### Structure by use case

| Need | Structure |
|---|---|
| Cache / session blob | `STRING` with `EX`; `HASH` when fields are updated independently |
| Counter, rate limit | `INCR` + `EXPIRE` on first hit (one `SET k 0 EX 60 NX` then `INCR`) |
| Leaderboard, scheduled jobs by time | `ZSET` (`ZADD`, `ZRANGEBYSCORE`) |
| Recent-N list | `LPUSH` + `LTRIM` |
| Unique visitors (approximate) | `HyperLogLog` (`PFADD`/`PFCOUNT`) |
| Membership | `SET` ; `SISMEMBER` |
| Queue / event log | `STREAM` with consumer groups (see below) |

### What must not live only in Redis

Anything you cannot regenerate: orders, balances, audit records. Redis is a cache and a coordination
layer; persistence (RDB snapshots at intervals, AOF `appendfsync everysec`) narrows the loss window,
it does not make it a system of record. `everysec` loses up to a second; `always` costs every write.

### Distributed locks

```lua
-- acquire: one command, token identifies the owner, TTL bounds the hold
SET lock:invoice:42 <random_token> NX PX 10000

-- release: check-and-delete in ONE script (two commands = delete someone else's lock after your TTL expired)
if redis.call("GET", KEYS[1]) == ARGV[1] then return redis.call("DEL", KEYS[1]) else return 0 end
```

Rules: never `SETNX` + `EXPIRE` as two commands (crash between them = lock without TTL); the TTL is
longer than the worst-case work or the work renews it; a lost lock during a GC pause is still
possible, so the protected operation is idempotent (fencing token when correctness matters). Redlock
across independent nodes is contested; single-instance lock + idempotent work is the honest default.

### Queues

```
# Streams: durable, consumer groups, pending list, acknowledge
XADD jobs * type email id 7001
XREADGROUP GROUP workers w1 COUNT 10 BLOCK 5000 STREAMS jobs >
XACK jobs workers <id>              # after the work; XAUTOCLAIM re-delivers stale pending entries
```

Reliable list for simple cases: `LMOVE jobs processing RIGHT LEFT`, remove from `processing` on
success, a sweeper re-queues what stays there. Plain `LPOP` loses the job on a worker crash.
`MAXLEN ~ 100000` on `XADD` so the stream does not grow forever.

### Big keys and KEYS

- `KEYS pattern` blocks the whole server for the scan; `SCAN` with a cursor in batches, always.
- A hash with 5 million fields or a list with 10 million items: `DEL` blocks for seconds (`UNLINK`
  frees asynchronously); split by range, or set TTLs so it never grows there.
- `SMEMBERS`, `HGETALL`, `LRANGE 0 -1` on a big key is the same problem on the read side: `SSCAN`, `HSCAN`, bounded `LRANGE`.
- `redis-cli --bigkeys` and `MEMORY USAGE key` find them.

### Dragonfly

Redis-API-compatible (RESP protocol, same clients, same commands for the common set), different
internals. What is certain from its design:

- **Multi-threaded, shared-nothing**: keyspace is sharded across threads inside one process; a single
  instance scales with cores where Redis executes commands on one thread. Expect higher throughput per
  node for simple commands; multi-key commands coordinate across shards and cost relatively more.
- **Memory**: a different hash-table design (dashtable) and no fork for snapshots; Redis `BGSAVE`
  can transiently double memory on a write-heavy instance, Dragonfly snapshots without the fork.
- **Persistence**: snapshots (RDB-compatible format plus its own), no append-only file in the Redis
  sense. If AOF `everysec` was the durability story, it is not the same here.
- **Lua and transactions**: `EVAL`, `MULTI`/`EXEC` are supported; scripts that touch keys outside
  `KEYS[]` (undeclared keys) behave differently from Redis; declare every key.

Verify against the Dragonfly docs for your version: exact unsupported commands and modules (RedisJSON
/ search / Bloom are partially implemented and change per release); cluster-mode emulation vs real
cluster; keyspace notifications coverage; `WAIT`/replication semantics; default `maxmemory` policy
and eviction behaviour under its memory accounting; `CONFIG` parameters that exist in Redis but
not here; client-side caching (`CLIENT TRACKING`). None of these should be assumed from Redis
experience.

## ClickHouse

### Tables

- `MergeTree` family for everything real; `ReplicatedMergeTree` on a cluster; `Log` engines for tiny temporary data.
- `ORDER BY` **is** the primary index (sparse, one mark per 8 192 rows): put the columns the WHERE
  filters by first, low cardinality before high (`(tenant_id, event_type, toDate(ts), ts)`).
- `PARTITION BY toYYYYMM(ts)`: partitions are for lifecycle (drop a month, `TTL ts + INTERVAL 13 MONTH`)
  and for pruning; hundreds of partitions or partitioning by a high-cardinality key kills merges.
- `LowCardinality(String)` for enum-like strings; `DateTime64(3, 'UTC')`; `Decimal(19,4)` for money; never `Nullable` by reflex (extra column, slower).

```sql
CREATE TABLE page_events (
  tenant_id   UInt32,
  event_type  LowCardinality(String),
  ts          DateTime64(3, 'UTC'),
  session_id  UUID,
  duration_ms UInt32
) ENGINE = MergeTree
PARTITION BY toYYYYMM(ts)
ORDER BY (tenant_id, event_type, ts)
TTL toDateTime(ts) + INTERVAL 13 MONTH;
```

### Inserts

- Thousands to hundreds of thousands of rows per `INSERT`, once per second or slower; row-by-row
  inserts create a part each and the server throws `Too many parts`. Buffer in the app, or use
  `async_insert = 1` so the server batches.
- Inserts are atomic per part, not per statement across tables; duplicates from a retried batch are
  deduplicated only for identical blocks on Replicated tables (`insert_deduplicate`).

### No UPDATE as a habit

- `ALTER TABLE ... UPDATE/DELETE` are **mutations**: asynchronous rewrites of whole parts, meant
  for GDPR erasure and rare fixes, not for application logic. Lightweight `DELETE` (23.x) is cheaper
  but still not a row-store delete.
- No transactions across statements (experimental support exists; do not design on it).
- Changing a value: insert a new row and dedupe on read.

### Deduplication

```sql
ENGINE = ReplacingMergeTree(version) ORDER BY (tenant_id, entity_id)
-- reads: SELECT ... FROM t FINAL  → merges at read time, slow on big tables
-- or:    SELECT argMax(col, version) ... GROUP BY tenant_id, entity_id
```

`FINAL` is correct and costly; aggregate with `argMax` on hot paths, `OPTIMIZE ... FINAL` only in maintenance windows.
`CollapsingMergeTree` / `VersionedCollapsingMergeTree` for sign-based cancellation when the writer knows the old row.

### Materialised views

An insert trigger, not a cached query: rows inserted into the source table are transformed and
written into the target table (`SummingMergeTree` / `AggregatingMergeTree` with `-State` combinators).
Existing data is not backfilled by the view; `POPULATE` or a manual `INSERT ... SELECT` for history.
A failing MV fails the source insert.

### Queries

- Filter on the leading `ORDER BY` columns and on the partition key; `WHERE session_id = ?` alone scans everything (data-skipping indexes: `bloom_filter` on the column helps, is not a primary index).
- `SELECT *` on a 60-column wide table reads 60 column files; name the columns.
- `JOIN`: the right side is loaded into memory; put the small table on the right, or use `Dictionary` for lookups.
- `max_execution_time`, `max_memory_usage` per user profile so one analyst's query does not take the node.

## Elasticsearch / OpenSearch

### Mappings

- A field's mapping is immutable once set; changing `text` → `keyword` means a new index and a reindex.
- Dynamic mapping off in production: `"dynamic": "strict"` (reject unknown fields) or `"false"`
  (store, do not index); with it on, the first document decides every field's type for everyone.
- `keyword` for ids, statuses, exact filters and aggregations; `text` with an analyzer for search;
  both via `fields` (`title` text + `title.raw` keyword) when both are needed.
- Analyzer chosen per language and tested with `_analyze`; a standard analyzer on Russian text has no stemming.
- `index: false` on fields only returned, never searched; `_source` filtering on reads.

```json
PUT catalogue_v3
{ "mappings": { "dynamic": "strict", "properties": {
    "sku":      { "type": "keyword" },
    "title":    { "type": "text", "analyzer": "russian", "fields": { "raw": { "type": "keyword" } } },
    "price":    { "type": "scaled_float", "scaling_factor": 100 },
    "added_at": { "type": "date" } } } }
```

### Zero-downtime reindex via alias

```
1. create catalogue_v3 with the new mapping
2. POST _reindex { source: catalogue_v2, dest: catalogue_v3 }   (app keeps writing to v2 through the alias)
3. replay or dual-write changes made during step 2 (or do step 2 twice with a timestamp filter)
4. POST _aliases { actions: [ { remove: { index: catalogue_v2, alias: catalogue } },
                              { add:    { index: catalogue_v3, alias: catalogue } } ] }   — atomic
5. delete catalogue_v2 after verification
```

The application only ever knows the alias `catalogue`.

### Index lifecycle

Time-series data gets an index per day/week and an ILM (ES) / ISM (OpenSearch) policy: hot → warm →
delete; rollover by size or age via a write alias. One index with three years of logs cannot be
deleted partially and has too many shards or too big ones. Aim for shards of 10–50 GB; thousands of
tiny shards exhaust the master.

### Pagination

- `from` + `size` is capped at 10 000 (`index.max_result_window`) and costs `from + size` per shard; deep paging is `search_after` with a sort on `(field, _id or a tiebreaker)` and, for a consistent snapshot, a point-in-time (`PIT`).
- `scroll` is for exports and reindex jobs, not for user pagination.

### Indexing throughput

- `_bulk` in batches of 5–15 MB; never one document per request from a loop.
- During a big load: `index.refresh_interval: "30s"` or `-1`, `number_of_replicas: 0`, then restore.
  Default refresh every 1 s makes a write visible to search; `refresh=wait_for` on a single write that
  the user must see immediately, never `refresh=true` on every write.
- Results are **near** real time; a test that writes and searches in the same millisecond is flaky by design.

### It is not the source of truth

Documents in the index are a projection of rows elsewhere (the relational database, the event log).
Rebuilding the index from the source must always be possible; the write path is «commit to the
database, then index (outbox, CDC or a queue)», and an indexing failure is retried, not ignored.
Aggregations are approximate under some conditions (`terms` with many shards, `cardinality` is
HyperLogLog); a finance report comes from the database.
