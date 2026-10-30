# CI Security — permissions, untrusted PRs, pinning, secrets in logs

GitHub Actions first, GitLab CI where it differs. Pipeline structure, caching and deployment live
in `devops-patterns` `references/ci.md`; this file covers only what makes a workflow a security
finding. Every sample is invented.

## Workflow permissions

The default `GITHUB_TOKEN` scope is whatever the repository setting says, which is often
read-write for everything. Set it explicitly at the top and widen per job.

```yaml
# BAD — nothing stated: inherits the repository default, often write-all
on: [pull_request]
jobs:
  lint:
    runs-on: ubuntu-24.04

# GOOD — read by default, one job widened with the reason
permissions:
  contents: read
jobs:
  lint:
    runs-on: ubuntu-24.04
  release:
    permissions:
      contents: write      # creates the tag and the release
      id-token: write      # OIDC to the registry; no long-lived key
```

Finding when: `permissions: write-all`, `contents: write` on a job that only reads, `packages:
write` or `pull-requests: write` where nothing is published or commented, or no `permissions:`
block at all in a repository whose default is write.

GitLab: the job token's scope is a project setting («Limit access to this project»); a job that
needs `api` scope uses a project access token with the narrowest role, masked and protected,
never a personal token.

## Untrusted pull requests

`pull_request` from a fork runs with a read-only token and no secrets: safe by construction.
`pull_request_target` runs in the context of the base branch **with secrets**, on code the PR
author controls if the workflow checks out the PR head.

```yaml
# BAD — CRITICAL: the PR author's code runs with the base repo's secrets
on: pull_request_target
jobs:
  test:
    steps:
      - uses: actions/checkout@<sha>
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: npm ci && npm test        # package.json scripts from the PR, secrets in env
```

Fixes, in order of preference:

1. Use `pull_request`; label or comment from a separate `workflow_run` job that has the token.
2. Keep `pull_request_target` only for jobs that never check out or execute PR code (a labeler
   reading the event payload).
3. If PR code must run with a privilege, split: an unprivileged job builds and uploads an
   artifact; a privileged job downloads it and acts on it without executing it.

Same shape in GitLab: a pipeline for a fork MR runs in the fork's project and has no protected
variables unless «pipelines for merge requests from forks run in the parent project» is enabled;
if it is, protected variables are exposed to fork code. Treat that setting plus a protected
variable as the finding.

Other injection points from PR content: `${{ github.event.pull_request.title }}`,
`${{ github.event.issue.body }}`, `${{ github.head_ref }}` interpolated into `run:` are shell
injection. Pass them through `env:` and quote.

```yaml
# BAD
- run: echo "Reviewing ${{ github.event.pull_request.title }}"
# GOOD
- env:
    TITLE: ${{ github.event.pull_request.title }}
  run: echo "Reviewing $TITLE"
```

## Pinning

An action referenced by a mutable tag is code that can change under the workflow without a diff.

```yaml
# BAD
- uses: actions/checkout@v4
- uses: some-org/deploy-action@main
# GOOD
- uses: actions/checkout@<40-char-sha>  # v4.2.2
```

Same for images (`image: python:3.12-slim@sha256:…` in GitLab, `container:` in GitHub), for
tools downloaded in a step (a version and a checksum, never `curl … | bash` from a moving URL),
and for third-party reusable workflows (`uses: org/repo/.github/workflows/x.yml@<sha>`).

Severity: MEDIUM by default; HIGH when the unpinned action runs in a job with secrets or
`contents: write`; a tag from an unknown third party in a release job is CRITICAL in effect
(supply chain with write access).

## Secrets in logs and artifacts

Masking hides a secret only when it is printed verbatim. Encoded, split, or inside a JSON blob
it is not masked.

Finding when:

- `set -x` or `bash -x` in a step whose environment holds a secret.
- `env`, `printenv`, `cat .env`, `echo "$TOKEN"` or a verbose client (`curl -v` prints the
  `Authorization` header) in a step with secrets.
- A test or build failure prints its configuration, including connection strings.
- A secret written into an artifact: `.env` in the uploaded bundle, a `terraform plan` output
  containing a password, a built image with a build `ARG` that held a token (`docker history`
  shows it; use `--mount=type=secret`).
- A secret passed on the command line (`--password=…`), visible in the process list of the runner
  and often in the step's log.
- `secrets.*` referenced in a job triggered by untrusted input (see above).

GitLab: a variable not marked **masked** prints in plain text; a masked variable still prints if
the value does not satisfy the masking rules (too short, forbidden characters). Both masked and
protected is the expected state for anything that deploys.

## Checklist for a reviewed workflow change

- `permissions:` stated at the top, read-only by default, widened per job with a comment.
- No `pull_request_target` with PR-head checkout; no event payload interpolated into `run:`.
- Every `uses:` by SHA; every image by digest; every downloaded tool by version and checksum.
- No `set -x`, `env`, `printenv` or `-v` client flag in a step with secrets.
- Secrets never in artifacts, build args or the command line.
- A deploy job restricted to protected branches or environments with required reviewers; a tag
  that deploys to production cannot be created by the PR workflow.
