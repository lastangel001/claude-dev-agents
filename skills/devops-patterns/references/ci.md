# CI Patterns — GitLab CI and GitHub Actions

Both platforms shown wherever syntax differs, GitLab first. Jenkins at the end. Every sample is
invented: `ledger-api` is a made-up service, every SHA is a placeholder.

## Pipeline Structure

Fast feedback first, then build, then the slow suites, then deploy. Fan out what is independent,
fan in before anything that costs money.

```yaml
# .gitlab-ci.yml — stages give order; `needs:` turns it into a DAG
stages: [check, build, test, deploy]

lint:      { stage: check, script: [make lint] }
unit:      { stage: check, script: [make test-unit] }
build:
  stage: build
  needs: [lint, unit]                 # starts as soon as both pass, ignores other check jobs
  script: [make image]
integration:
  stage: test
  needs: [build]
  script: [make test-integration]
e2e:
  stage: test
  needs: [build]                      # fan-out: runs in parallel with integration
  script: [make test-e2e]
deploy-staging:
  stage: deploy
  needs: [integration, e2e]           # fan-in
  script: [make deploy ENV=staging]
```

```yaml
# .github/workflows/ci.yml — `needs:` is the only ordering; no stages
jobs:
  lint:        { runs-on: ubuntu-24.04, steps: [ ... ] }
  unit:        { runs-on: ubuntu-24.04, steps: [ ... ] }
  build:       { needs: [lint, unit], runs-on: ubuntu-24.04, steps: [ ... ] }
  integration: { needs: build, runs-on: ubuntu-24.04, steps: [ ... ] }
  e2e:         { needs: build, runs-on: ubuntu-24.04, steps: [ ... ] }
  deploy-staging: { needs: [integration, e2e], runs-on: ubuntu-24.04, steps: [ ... ] }
```

Always: `timeout-minutes:` / `timeout:` on every job, and a concurrency group that cancels a
superseded run on the same ref (`concurrency: {group: ci-${{ github.ref }}, cancel-in-progress: true}`;
GitLab: `interruptible: true` on pre-deploy jobs plus the project setting «auto-cancel redundant pipelines»).

## Caching Keyed on the Lockfile

A cache keyed on the branch never hits on a new branch and never invalidates when the lockfile
changes. Key on the content that determines the cache.

```yaml
# GitLab
cache:
  key:
    files: [package-lock.json]        # hash of the file; fallback key optional
  paths: [.npm/]
  policy: pull-push                   # `pull` on jobs that only read
script:
  - npm ci --cache .npm --prefer-offline
```

```yaml
# GitHub Actions
- uses: actions/cache@1bd1e32a3bdc45362d1e726936510720a7c30a57 # v4.2.0
  with:
    path: ~/.npm
    key: npm-${{ runner.os }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: npm-${{ runner.os }}-
- run: npm ci
```

Docker layers: `docker build --cache-from type=registry,ref=registry.example.test/ledger-api:cache`
with `--cache-to` on the same ref (GitLab), or `cache-from: type=gha` / `cache-to: type=gha,mode=max`
(GitHub). Cache hit rate is a metric; a cache that never hits is pure overhead.

## Matrices

```yaml
# GitLab
test:
  parallel:
    matrix:
      - PHP: ["8.3", "8.4"]
        DB: [pgsql, mysql]
  image: php:${PHP}-cli@sha256:0000000000000000000000000000000000000000000000000000000000000000
  script: [make test DB=$DB]
```

```yaml
# GitHub Actions
test:
  strategy:
    fail-fast: false                  # see every failure, not just the first
    matrix:
      php: ["8.3", "8.4"]
      db: [pgsql, mysql]
  steps:
    - run: make test DB=${{ matrix.db }}
```

Keep the matrix minimal on MR/PR; expand to the full matrix on release branches or nightly.

## Artifacts and Retention

The image you tested is the image you deploy: build once, promote by digest, never rebuild per
environment. Pass small things (coverage, junit, the image digest) through the artifact store.

```yaml
# GitLab
build:
  script:
    - docker build -t "$IMAGE:$CI_COMMIT_SHA" .
    - docker push "$IMAGE:$CI_COMMIT_SHA"
    - docker inspect --format='{{index .RepoDigests 0}}' "$IMAGE:$CI_COMMIT_SHA" > image.digest
  artifacts:
    paths: [image.digest]
    reports: { junit: junit.xml }     # surfaces in the MR
    expire_in: 1 week                 # not forever
```

```yaml
# GitHub Actions
- uses: actions/upload-artifact@6f51ac03b9356f520e9adb1b1b7802705f340c2b # v4.5.0
  with: { name: image-digest, path: image.digest, retention-days: 7 }
```

## Permissions

```yaml
# GitHub Actions: deny at the top, widen per job
permissions: { contents: read }
jobs:
  publish:
    permissions:
      contents: read
      packages: write                 # only this job pushes the image
      id-token: write                 # only this job federates to the cloud
```

GitLab: `CI_JOB_TOKEN` is scoped by the project's «Limit access» settings; keep the allow-list
short. Mark deployment variables **protected** (only protected branches/tags see them) and
**masked**; bind deploy jobs to an **environment** with required approvers:

```yaml
deploy-prod:
  environment: { name: production, url: https://ledger.example.test }
  rules: [{ if: $CI_COMMIT_TAG }]
  script: [make deploy ENV=production]
```

## Pinning

- GitHub: third-party actions by full commit SHA with the version in a comment (Dependabot or
  Renovate keep the comment and the SHA in step). A major tag (`@v4`) is a moving reference.
- GitLab and Dockerfiles: images by digest, `image: alpine:3.21@sha256:…`.
- Tools installed in the job: exact version (`npm i -g pnpm@9.15.4`), never `curl https://…/install.sh | sh`.

## Secrets

- Names in the pipeline, values in the store: GitLab masked variables (value must be maskable,
  no multi-line in the mask-only mode), GitHub `secrets.NAME` (masked in logs automatically; a
  transformed value, base64 for instance, is not).
- Never `set -x` in a step that exports a secret; never `echo "$TOKEN"` to «debug».
- Cloud access through **OIDC**, not long-lived keys:

```yaml
# GitLab
deploy:
  id_tokens:
    AWS_TOKEN: { aud: https://gitlab.example.test }
  script:
    - aws sts assume-role-with-web-identity --role-arn "$DEPLOY_ROLE_ARN" --web-identity-token "$AWS_TOKEN" ...
```

```yaml
# GitHub Actions
- uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
  with: { role-to-assume: "${{ vars.DEPLOY_ROLE_ARN }}", aws-region: eu-central-1 }
```

The trust policy on the cloud side restricts `sub` to the repo and branch/environment; otherwise
every workflow in the org can assume the role.

## Fork Safety

- GitHub: `pull_request` from a fork runs with a read-only token and no secrets. Good.
  `pull_request_target` runs with the base repo's secrets; combined with
  `actions/checkout` of `${{ github.event.pull_request.head.sha }}` it executes attacker code
  with your secrets. Use it only to label or comment, never to build the PR's code.
- Never interpolate untrusted input (`github.event.pull_request.title`, branch names, issue
  bodies) into `run:`; pass it through `env:` and quote it.
- GitLab: protected variables are not exposed to MR pipelines from forks; keep it that way and do
  not «fix» a red fork pipeline by unprotecting a variable.

## When Jobs Run — `rules:` vs `on:`

```yaml
# GitLab: merge-request pipelines + default branch + tags, nothing else
workflow:
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG
deploy-prod:
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: manual                     # a gate, still visible in the pipeline
      allow_failure: false
```

```yaml
# GitHub Actions
on:
  pull_request: { branches: [main] }
  push: { branches: [main], tags: ["v*.*.*"] }
jobs:
  deploy-prod:
    if: startsWith(github.ref, 'refs/tags/v')
    environment: production            # required reviewers configured on the environment
```

`changes:` (GitLab) / `paths:` (GitHub) skip jobs for docs-only changes, but a required check
that is skipped must still report success (see the aggregator job).

## Reusable Templates

```yaml
# GitLab: include + extends
include:
  - project: platform/ci-templates
    ref: v3.2.0                        # pinned
    file: /templates/php.yml
test:
  extends: .php-test                   # hidden job from the template
  variables: { PHP: "8.4" }
```

```yaml
# GitHub: reusable workflow (a whole job graph) …
jobs:
  test:
    uses: example-org/ci-templates/.github/workflows/php-test.yml@3f4c9d2e1b0a… # v3.2.0
    with: { php: "8.4" }
    secrets: inherit
# … or a composite action (a step sequence), referenced by SHA the same way
```

## Test Splitting and Parallel Jobs

GitLab `parallel: 4` sets `CI_NODE_INDEX`/`CI_NODE_TOTAL`; GitHub uses a matrix `shard: [1, 2, 3, 4]`.
Split by recorded timings where the runner supports it (`pytest --splits 4 --group $CI_NODE_INDEX`
with pytest-split, Jest `--shard=1/4`, Playwright `--shard=1/4`), otherwise by file list. Collect
junit from every shard into one report. In a monorepo run only affected projects (`nx affected`,
`turbo run test --filter=...[origin/main]`, or GitLab `rules:changes` per path).

## Required Checks and the Aggregator Job

Branch protection should require **one** check whose name never changes, not every matrix leg.

```yaml
# GitHub Actions
ci-ok:
  needs: [lint, unit, build, integration, e2e]
  if: always()
  runs-on: ubuntu-24.04
  steps:
    - run: |
        echo '${{ toJSON(needs) }}' | jq -e 'all(.[]; .result == "success" or .result == "skipped")'
```

GitLab: the merge request requires «pipeline must succeed»; a last-stage job with
`needs:` on everything and `allow_failure: false` plays the same role when some jobs are optional.

## Jenkins — What Differs

- **Declarative pipeline** (`pipeline { agent … stages { stage('x') { steps { … } } } }`) in a
  `Jenkinsfile` at the repo root; scripted Groovy only for what declarative cannot express.
  `parallel { stage … }` for fan-out; `post { always { junit '...' } }` for reports.
- **Shared libraries** (`@Library('platform-ci@v3.2.0') _`) are the template mechanism; pin the
  library tag like any other dependency.
- **Credentials binding**: `withCredentials([string(credentialsId: 'registry-token', variable: 'TOKEN')]) { sh '…' }`
  masks the value in the console; never `sh "echo ${TOKEN}"` with Groovy interpolation, which
  leaks it into the log before masking.
- Agents are labelled (`agent { label 'linux-docker' }`); pin tool versions with `tools {}` or
  containers, never rely on what happens to be installed on a node.
- Validate with the linter endpoint (`curl -X POST -F "jenkinsfile=<Jenkinsfile" $JENKINS_URL/pipeline-model-converter/validate`)
  before pushing; a broken `Jenkinsfile` fails only when the job starts.
