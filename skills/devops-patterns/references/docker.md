# Docker Patterns

The image is the artifact: built once, scanned, promoted by digest. Every digest below is a
placeholder; replace with the real one from `docker buildx imagetools inspect`.

## Multi-Stage Builds per Stack

Build stage carries the toolchain; the final stage carries only what runs. Copy artifacts, not
source plus toolchain.

### PHP-FPM + nginx (two images, one compose/pod)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM composer:2.8@sha256:0000000000000000000000000000000000000000000000000000000000000000 AS deps
WORKDIR /app
COPY composer.json composer.lock ./
RUN --mount=type=cache,target=/tmp/cache \
    composer install --no-dev --no-scripts --no-autoloader --prefer-dist
COPY . .
RUN composer dump-autoload --optimize --classmap-authoritative

FROM php:8.4-fpm-alpine@sha256:0000000000000000000000000000000000000000000000000000000000000000 AS runtime
RUN apk add --no-cache tini icu-libs \
 && docker-php-ext-install -j"$(nproc)" opcache pdo_pgsql intl \
 && addgroup -g 1001 -S app && adduser -S app -u 1001 -G app
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/
WORKDIR /app
COPY --from=deps --chown=app:app /app /app
USER app
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD php-fpm-healthcheck || exit 1
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["php-fpm", "-F"]
```

nginx is its own image (`nginx:1.27-alpine@sha256:…`) with the compiled `public/` copied in and
`fastcgi_pass app:9000`; the two share a pod or a compose network. PHP source is not served by nginx.

### Python (uv, wheels built once)

```dockerfile
# syntax=docker/dockerfile:1.7
FROM python:3.12-slim@sha256:0000000000000000000000000000000000000000000000000000000000000000 AS build
COPY --from=ghcr.io/astral-sh/uv:0.5.11@sha256:0000000000000000000000000000000000000000000000000000000000000000 /uv /bin/uv
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
COPY pyproject.toml uv.lock ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev --no-install-project
COPY . .
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev

FROM python:3.12-slim@sha256:0000000000000000000000000000000000000000000000000000000000000000
RUN useradd -r -u 1001 app
WORKDIR /app
COPY --from=build --chown=app:app /app /app
ENV PATH=/app/.venv/bin:$PATH PYTHONUNBUFFERED=1
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request as u; u.urlopen('http://127.0.0.1:8000/health')" || exit 1
CMD ["gunicorn", "ledger.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

pip without uv: `pip wheel -r requirements.txt -w /wheels` in the build stage,
`pip install --no-index --find-links=/wheels -r requirements.txt` in the final one; `--require-hashes`
when the requirements file carries hashes.

### Node build, static output served by nginx

```dockerfile
# syntax=docker/dockerfile:1.7
FROM node:22.12-alpine@sha256:0000000000000000000000000000000000000000000000000000000000000000 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci
COPY . .
RUN npm run build                           # → /app/dist

FROM nginxinc/nginx-unprivileged:1.27-alpine@sha256:0000000000000000000000000000000000000000000000000000000000000000
COPY docker/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
```

A Node server (SSR, API): same build stage, then `npm ci --omit=dev` into a clean final stage,
`USER node`, `CMD ["node", "dist/server.js"]` (not `npm start`: npm does not forward signals).

## Pinning the Base Image

`FROM python:3.12-slim@sha256:…`: the tag documents intent, the digest guarantees the bytes.
Renovate or Dependabot bump the digest in a PR; `docker buildx imagetools inspect python:3.12-slim`
prints the current one. Build tools pulled with `COPY --from=image@sha256:…` are pinned the same way.

## Non-root User

Create the user in the final stage, `--chown` on every `COPY`, `USER app` before `CMD`. Ports
below 1024 need `CAP_NET_BIND_SERVICE` or, simpler, a port above 1024 (`nginx-unprivileged` listens
on 8080). If the process must write, give it one directory (`VOLUME` or an `emptyDir` in k8s) and
keep the rest read-only.

## `.dockerignore`

```
.git
.env
.env.*
node_modules
vendor
.venv
__pycache__
dist
coverage
*.log
docker-compose*.yml
Dockerfile*
tests/
docs/
```

Without it, `COPY . .` ships the git history, local secrets and the host's `node_modules`, and
invalidates the cache on every commit.

## Layer Ordering for Cache

Most stable first, most volatile last: base image → system packages → dependency manifests →
dependency install → source → build. `COPY package.json package-lock.json ./` then `RUN npm ci`
before `COPY . .`, so a source change does not reinstall dependencies. `--mount=type=cache` keeps
the package manager's cache across builds without putting it in a layer.

## HEALTHCHECK

`HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 CMD …`: a cheap local
check (the process answers), not a dependency check (the database is up); the latter belongs in a
readiness probe. Kubernetes ignores `HEALTHCHECK`, compose and Swarm honour it; ship it anyway so
`docker run` locally behaves like the cluster.

## Signals and PID 1

PID 1 does not get default signal handlers: `CMD npm start` or `CMD sh -c "…"` means `docker stop`
waits 10 s and kills. Either `ENTRYPOINT ["/sbin/tini", "--"]` (or `docker run --init`) or
`exec` the process from the entrypoint script:

```sh
#!/bin/sh
set -eu
# … environment prep …
exec "$@"                                   # the app becomes PID 1 under tini, receives SIGTERM
```

Match `terminationGracePeriodSeconds` / `stop_grace_period` to the app's real drain time.

## Build Args vs Runtime Env

`ARG` is a build-time value (version string, target architecture, a feature compiled in) and is
visible in `docker history`; `ENV` is runtime configuration. Never `ARG NPM_TOKEN`: it lands in the
image metadata. Configuration that differs per environment (database URL, log level) is runtime
env injected by the orchestrator, not baked in.

## Secrets at Build Time

```dockerfile
# syntax=docker/dockerfile:1.7
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc npm ci
RUN --mount=type=ssh git clone git@git.example.test:platform/private-lib.git
```

```sh
docker build --secret id=npmrc,src=$HOME/.npmrc --ssh default -t ledger-api .
```

The secret exists only during that `RUN`; it is in no layer and no history. In CI the source is a
masked variable written to a file in the job, never a committed file.

## Image Scanning as a CI Step

```yaml
# GitLab
scan:
  stage: test
  needs: [build]
  image: aquasec/trivy:0.58.1@sha256:0000000000000000000000000000000000000000000000000000000000000000
  script:
    - trivy image --exit-code 1 --severity CRITICAL,HIGH --ignore-unfixed "$IMAGE@$(cat image.digest)"
```

```yaml
# GitHub Actions
- uses: aquasecurity/trivy-action@18f2510ee396bbf400402947b394f2dd8c87dbb0 # 0.29.0
  with: { image-ref: "${{ env.IMAGE }}@${{ steps.build.outputs.digest }}", exit-code: "1", severity: "CRITICAL,HIGH", ignore-unfixed: "true" }
```

`grype` is interchangeable (`grype $IMAGE --fail-on high`). A `.trivyignore` entry carries the
CVE id, the reason and an expiry date; an ignore file with no dates is a muted scanner.

## Compose for Local Dev Only

```yaml
services:
  app:
    build: { context: ., target: build }    # the stage with the toolchain, for hot reload
    volumes: [".:/app", "/app/node_modules"] # bind source, protect container deps
    environment:
      DATABASE_URL: postgres://ledger:ledger@db:5432/ledger_dev
    depends_on:
      db: { condition: service_healthy }
  db:
    image: postgres:17-alpine@sha256:0000000000000000000000000000000000000000000000000000000000000000
    ports: ["127.0.0.1:5432:5432"]          # host only, not the LAN
    environment: { POSTGRES_USER: ledger, POSTGRES_PASSWORD: ledger, POSTGRES_DB: ledger_dev }
    healthcheck: { test: ["CMD-SHELL", "pg_isready -U ledger"], interval: 5s, retries: 5 }
    volumes: [pgdata:/var/lib/postgresql/data]
volumes: { pgdata: }
```

Compose is the developer's cluster: services resolve by name, `docker-compose.override.yml` holds
the local-only debug ports, a throwaway password in a dev-only compose file is fine. It is not a
production orchestrator: no rolling update, no PDB, no secret store. Production multi-container
workloads go to Kubernetes (or ECS/Nomad/Swarm if the project already runs them).

## Anti-patterns

- `FROM node` or `FROM node:latest`: a different image every week, no way to reproduce last month's build.
- Root in the final stage; `chmod -R 777` to make it work.
- `COPY . .` as the first instruction: every commit rebuilds every layer.
- Dev dependencies, compilers and test suites in the production image.
- `ENV API_KEY=…` or `ARG TOKEN` used in a `RUN`: readable by anyone who pulls the image.
- `CMD npm start` / `CMD sh -c` without `exec`: the app never sees SIGTERM.
- A `HEALTHCHECK` that calls the database: one slow query marks every container unhealthy.
- Compose in production with `restart: always` as the «orchestration».
