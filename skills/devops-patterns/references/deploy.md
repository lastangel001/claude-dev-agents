# Deployment Strategies and Release Practice

A deploy is a change to production with a known way back. Service names and numbers below are
invented.

## Strategies

| Strategy | Mechanism | Rollback | Cost | Use when |
|---|---|---|---|---|
| **Rolling** (default) | replace pods one batch at a time; both versions serve during the rollout | redeploy previous digest; pods roll back the same way | none extra | stateless services, backward-compatible changes |
| **Blue-green** | second full environment, switch traffic atomically at the load balancer or Service selector | flip the switch back (seconds) | 2× capacity during the deploy | instant cutover needed, long-running connections, big-bang changes you can still undo |
| **Canary** | 1–5 % of traffic to the new version, widen in steps gated by metrics | route 0 % to canary, scale it down | traffic splitting (service mesh, ingress weights, Argo Rollouts / Flagger) | high traffic, risky changes, real users as the test |

Rolling requires the two versions to coexist: same API contract, same schema (see migration
ordering below). Blue-green with a shared database is still rolling for the database. A canary
without metrics and an automated abort is a slow rolling update with extra steps.

### Canary with metric gates

```yaml
# Argo Rollouts (Flagger has the same shape)
strategy:
  canary:
    steps:
      - setWeight: 5
      - pause: { duration: 10m }
      - analysis: { templates: [{ templateName: error-rate }] }   # abort → automatic rollback
      - setWeight: 25
      - pause: { duration: 10m }
      - setWeight: 50
      - pause: { duration: 10m }
```

The gate compares the canary to the stable version on the same window: error rate not more than
0.5 percentage points worse, p95 latency not more than 20 % worse, no new alert firing. Compare,
do not use an absolute threshold; a quiet night passes anything.

## Feature Flags vs Deploys

Deploy ships code; the flag releases behaviour. Risky behaviour goes behind a flag so turning it
off is a config change, not a rollback. Rules: default off in production, owner and removal date
on every flag, flag state in one store (not an env var per replica), a flag flip is logged like a
deploy. Flags are not a substitute for backward-compatible schema changes: the old code path still
runs against the new schema.

## Migration Ordering — Expand → Deploy → Contract

Every schema change spans at least two releases so that the running code and the schema are
compatible at every moment, including during the rollback.

```
Release N:    1. expand migration (add column / table / index, nullable, additive)
              2. deploy code that writes both and reads old   ← can roll back to N-1 freely
Release N+1:  3. deploy code that reads new (writes both)     ← can roll back to N
Release N+2:  4. contract migration (drop old)                 ← only after N+1 is stable and nothing reads old
```

The migration runs once, as a Job or pipeline step, **before** the code that needs it and
**after** the code that stops needing the old shape. Never in the application's entrypoint on a
multi-replica deploy. The SQL for each step (concurrent indexes, batched backfills, lock timeouts)
is in `sql-patterns`, `references/migrations.md`.

## Rollback Runbook Template

Written next to the deploy config, before the first production deploy, filled in per service:

```markdown
## Rollback — ledger-api

**Trigger** (any one): error rate > 2 % for 5 min · p95 > 800 ms for 10 min · the smoke check fails ·
on-call judgement.
**Decides:** the on-call engineer; the release owner is informed, not asked. No committee.

**What to run**
1. `helm rollback ledger-api --namespace ledger` (previous release) — or in the pipeline:
   re-run `deploy-prod` with `IMAGE_DIGEST=<previous digest from the release notes>`.
2. If a feature flag was enabled for this release: `flagctl set ledger.new-invoicing off` first;
   it may be enough.
3. Schema: this release ran expand migration 0142 (additive). **Do not revert it.** The previous
   code ignores the new column. If 0142 must go, write migration 0143 that drops it, next release.

**What to watch** (dashboard «ledger-api / release»): error rate back under 0.5 % within 2 min of
the rollout finishing; p95; `kubectl rollout status`; the queue depth on `ledger-events`.

**After**: incident note with timeline; the bad digest marked in the registry; the fix ships as a
new release, never by re-deploying the bad one «once the DB is fixed».
```

### Database rollback is a forward migration

`down()` ran against a column that received an hour of production writes destroys data. The
recovery for a bad migration is the next migration (drop the half-made index, add the column
back, fix the backfill); the code rollback stays independent of it because the expand step was
additive. The only exception is a migration that failed inside its own transaction and left nothing
behind.

## Release Tagging and Changelog

- One immutable identifier per release: a SemVer tag (`v2.14.0`) for products and libraries, the
  git SHA for continuous-deploy services; the image digest recorded in the release notes either way.
- Tag → pipeline → deploy, never deploy → tag afterwards: the tag is what triggers the protected job.
- Changelog from conventional commits or MR labels, kept with the code (`CHANGELOG.md`), one
  section per release with the migrations it contains and the flags it introduces.
- Hotfix: branch from the tag, fix, tag `v2.14.1`, merge back; not a cherry-pick applied by hand to a server.

## Post-deploy Verification

Inside the pipeline, after the rollout finishes and before the job is green:

```sh
# smoke: the new version answers and is the version we meant
curl -fsS --max-time 5 https://ledger.example.test/health | jq -e '.version == "2.14.0"'
# key transaction, read-only or against a synthetic account
curl -fsS --max-time 5 -H "Authorization: Bearer $SMOKE_TOKEN" \
  https://ledger.example.test/api/v1/accounts/synthetic-0001 | jq -e '.balance != null'
```

Then a synthetic check (Blackbox exporter, an uptime probe, a scheduled Playwright flow) keeps
hitting the same path every minute; its alert is the first signal most regressions produce. A deploy
marker (annotation in Grafana, an event in the APM) on every rollout so a latency step maps to a release.

## Freeze Windows

Named, dated, in the calendar and in the pipeline (`rules: - if: $DEPLOY_FREEZE == "true" when: manual`):
end-of-quarter closing, a marketing peak, the holiday on-call gap. During a freeze only a
rollback or a hotfix with an incident number deploys, approved by the on-call lead. A freeze that
lasts longer than two weeks is a sign the deploy is not safe enough, not a process to keep.

## Anti-patterns

- A deploy with no rollback command written down; «we would figure it out».
- Canary without metrics or with an absolute threshold; a 1 % canary that stays at 1 % for a day.
- Migration in the entrypoint; migration and code in the same rollout with no expand step.
- `down()` run in production as the rollback.
- Deploying by `latest`, or re-tagging a different build with the same version.
- Verifying a deploy by watching the pod go green; the readiness probe is not a smoke test.
- A feature flag that has been «temporarily» on since last year.
