---
name: devops-patterns
description: Delivery-infrastructure patterns for builders and reviewers — CI on GitLab CI and GitHub Actions as equals (stages and DAGs, lockfile-keyed caches, matrices, minimal permissions, SHA/digest pinning, OIDC instead of long-lived keys, fork safety, reusable templates, aggregator checks) with a Jenkins differences section; Docker multi-stage builds per stack, digest pinning, non-root, BuildKit secrets, image scanning; Kubernetes workloads (requests/limits, the three probes, PDB, HPA, NetworkPolicy, RBAC, migration Jobs) and Helm charts; Terraform and Ansible; rolling, blue-green and canary deploys with the expand → deploy → contract migration order and a rollback runbook; observability (three signals, RED/USE, SLOs, symptom alerts). Activate when writing, reviewing or planning pipelines, images, manifests, charts, infrastructure or releases, or on «настрой CI», «пайплайн GitLab», «GitHub Actions», «Dockerfile», «Helm-чарт», «деплой», «откат», «canary», «Terraform», «алерты», «set up CI», «write a Dockerfile», «deploy strategy», «rollback plan».
---

# DevOps Patterns

Patterns for the path between a commit and a running service. Targets: **GitLab CI and GitHub
Actions** as equals (Jenkins: a differences section), **Docker**, **Kubernetes + Helm**,
**Terraform and Ansible**, release and rollback practice, observability.

## When to Activate

Activate this skill whenever the user (or an agent's task) involves:

- Writing or reviewing a pipeline, a Dockerfile, a manifest, a chart, a Terraform module, a playbook
- Choosing a deploy strategy, planning a rollback, ordering a migration against a deploy
- Setting up alerts, dashboards, logs or tracing for a service
- Making a pipeline faster, cheaper or less flaky
- Trigger phrases: «настрой CI», «пайплайн GitLab», «GitHub Actions», «Dockerfile», «Helm-чарт»,
  «деплой», «откат», «canary», «Terraform», «алерты», «set up CI», «write a Dockerfile»,
  «deploy strategy», «rollback plan»

## Reference Routing — read only what the task needs

| Task at hand | Read |
|---|---|
| Stages and DAGs, caching, matrices, artifacts, permissions, pinning, secrets and OIDC, fork safety, `rules:` vs `on:`, templates, test splitting, aggregator job, Jenkins differences | [references/ci.md](references/ci.md) |
| Multi-stage builds (PHP-FPM + nginx, Python, Node → static), digest pinning, non-root, `.dockerignore`, layer order, `HEALTHCHECK`, PID 1, build args vs env, BuildKit secrets, scanning, compose | [references/docker.md](references/docker.md) |
| Deployment, requests/limits, probes, PDB, HPA, ConfigMap/Secret and ESO, rolling parameters, migration Jobs, NetworkPolicy, RBAC, labels; Helm layout, per-env values, lint/template in CI, `--atomic`, versioning; kustomize | [references/kubernetes.md](references/kubernetes.md) |
| Terraform state and locking, modules, plan as artifact, validation, `moved`, drift, workspaces vs directories, provider pinning; Ansible idempotency, check mode, vault, inventories, handlers, lint | [references/iac.md](references/iac.md) |
| Rolling / blue-green / canary, feature flags, expand → deploy → contract, rollback runbook, release tagging, post-deploy verification, freeze windows | [references/deploy.md](references/deploy.md) |
| Three signals, structured logs and correlation ids, metric naming, RED/USE, SLOs and error budgets, symptom alerts with runbooks, dashboards, tracing, retention | [references/observability.md](references/observability.md) |

Migrations themselves (expand-contract SQL, concurrent indexes, backfills) live in the
`sql-patterns` skill, `references/migrations.md`; this skill covers the deploy ordering around them.

## Core Principles

1. **Pin everything.** Actions by SHA, images by digest, charts, providers, modules and tools by
   exact version. A moving reference is an unreviewed change arriving at an unknown time.
2. **Least privilege by default.** Minimal `permissions:` per job, protected variables, RBAC per
   workload, non-root containers. Widen one scope with a comment that says why.
3. **Idempotent and re-runnable.** Every job, script and playbook is safe to run twice; a retry
   must never be the thing that breaks production.
4. **Rollback is designed before rollout.** The previous image digest, the migration posture and
   the command to go back are written next to the deploy, not invented during the incident.
5. **Measure before optimising a pipeline.** Read the job timings, fix the top sink, re-measure.
   A cache tuned on a pipeline whose time sits in an unparallelised suite changes nothing.
6. **Secrets never in files or logs, names only.** The pipeline references `DB_PASSWORD`; the
   value lives in the secret store. Masked variables, OIDC federation, no `echo` of anything secret.
7. **One source of truth for config.** Per-environment values in one place (values file, tfvars,
   inventory), not scattered across a workflow, a Dockerfile and a chart.
8. **Alert on symptoms, not causes.** Error rate, latency and saturation against an SLO page a
   human; CPU at 80 % is a dashboard panel.

## Quick Reference

| Need | Pattern |
|---|---|
| Pin a GitHub action | `uses: actions/checkout@<40-char-sha> # v4.2.2` |
| Pin an image | `FROM python:3.12-slim@sha256:…` (GitLab `image:` the same way) |
| Cache deps | GitLab `cache:key:files: [package-lock.json]`; GH `key: ${{ hashFiles('**/package-lock.json') }}` |
| Job permissions | GH `permissions: {contents: read}` at top, widen per job; GitLab protected + masked variables |
| Cloud creds in CI | OIDC: GH `id-token: write` + `aws-actions/configure-aws-credentials`; GitLab `id_tokens:` |
| Fork PR safety | never `pull_request_target` with checkout of the PR head; GitLab: no protected vars on fork MRs |
| Required checks | one `ci-ok` aggregator job with `needs: [all]` and `if: always()`; GitLab: last stage job |
| Image hygiene | multi-stage, `USER app`, `.dockerignore`, `HEALTHCHECK`, `tini` or `exec` for PID 1 |
| Build-time secret | `RUN --mount=type=secret,id=npmrc …`, never `ARG TOKEN` |
| Probes | startup covers slow boot; liveness = hung process; readiness = can take traffic now |
| Migration on k8s | one `Job` (or Helm pre-upgrade hook) with `completions: 1`, never in the app's entrypoint |
| Helm in CI | `helm lint` → `helm template \| kubeconform` → `helm upgrade --install --atomic --wait` |
| Terraform in CI | `plan -out=tf.plan` as artifact on MR/PR → human review → `apply tf.plan` on merge |
| Ansible in CI | `ansible-lint` + `--check --diff` on MR/PR; `ansible-vault` for secrets |
| Deploy order with schema change | expand migration → deploy code → verify → contract migration (next release) |
| Rollback | redeploy previous digest; schema goes forward only (a new migration), never `down` in prod |
| Alert | `rate(http_requests_total{code=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.01` + runbook URL |

## Anti-Patterns to Avoid

The linter does not catch these; a reviewer must.

- Unpinned actions, images or tools, `latest` anywhere on the path to production.
- `permissions: write-all`, a job token with `api` scope, a deploy key with write on every repo.
- A cache keyed on the branch name: never hits on a new branch, never invalidates on a lockfile change.
- Secrets echoed in logs: `set -x` with a token in the env, `cat .env`, a `terraform plan` that prints a password.
- `kubectl apply` or `helm upgrade` from a laptop: no record, no review, no repeatable rollback.
- No resource requests or limits: one pod evicts the rest of the node.
- Migrations run from application startup on a multi-replica deploy: n replicas race the same DDL.
- `terraform apply` without a reviewed plan, or `-auto-approve` on a human-triggered run.
- Alerts on CPU or memory instead of error rate and latency: pages at 3 a.m. for nothing a user feels.

__Remember__: the pipeline is production code that runs with production credentials. Pin it,
review it, give it only what it needs, and know the way back before you go forward.

Docker, Kubernetes and deployment sections distilled from [affaan-m/ECC](https://github.com/affaan-m/ECC) `docker-patterns`, `kubernetes-patterns`, `deployment-patterns` and `github-ops` (MIT).
