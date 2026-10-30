# Audit Tooling — read-only, per stack, never installed

Rules that hold for every command here:

- **Run only what is already present** in the project or on the PATH. Never install a tool, never
  add a dev dependency to run it, never `npx` or `pipx run` a package that is not already there.
- **Never modify**: no `--fix`, no lockfile update, no `composer update`, no `npm audit fix`.
- **Report by name**: every tool that ran, with its advisory count from its own output; every
  tool that was absent as «not checked». An unchecked family is never reported as clean.
- **Figures from output only**: an advisory count comes from the tool's output, never from memory
  of a CVE or from the advisory database's web page.

Check presence first (`command -v composer`, `command -v pip-audit`, …) and read the project's
manifest to know which stacks apply.

## Per stack

| Stack | Presence check | Command (read-only) | Reads | Notes |
|---|---|---|---|---|
| PHP / Composer | `composer --version` | `composer audit --format=plain` | `composer.lock` | Composer ≥ 2.4; `--locked` reads the lockfile without resolving; exit code 1 means advisories found, not a tool error |
| Python / pip | `pip-audit --version` | `pip-audit -r requirements.txt` or `pip-audit` in the venv | requirements or the installed environment | Alternative if present: `safety check -r requirements.txt`; with `uv`: `uv pip list` plus `pip-audit --no-deps` on the export |
| Python / Poetry | `poetry --version` | `poetry export -f requirements.txt --without-hashes \| pip-audit -r /dev/stdin` | `poetry.lock` | Only when `pip-audit` is also present; `poetry audit` exists only as a plugin |
| Node / npm | `npm --version` | `npm audit --omit=dev --audit-level=high` | `package-lock.json` | `--omit=dev` keeps dev-only advisories out of the production count; report both when the brief asks |
| Node / pnpm | `pnpm --version` | `pnpm audit --prod` | `pnpm-lock.yaml` | |
| Node / Yarn | `yarn --version` | `yarn npm audit --environment production` (Berry) / `yarn audit --groups dependencies` (Classic) | `yarn.lock` | Classic's exit code is a bitmask of severities |
| Go | `govulncheck -version` | `govulncheck ./...` | `go.mod`, `go.sum`, the call graph | Symbol-level: reports only reachable vulnerable functions; say so when the count is zero |
| Rust | `cargo audit --version` | `cargo audit` | `Cargo.lock` | A cargo subcommand that must already be installed |
| Ruby | `bundle audit --version` | `bundle audit check` (no `--update`) | `Gemfile.lock` | `--update` would fetch the database; skip it and say the database age is unknown |
| .NET | `dotnet --version` | `dotnet list package --vulnerable --include-transitive` | project files, `packages.lock.json` | Needs a restore to have happened |
| Java / Maven | `mvn --version` | `mvn org.owasp:dependency-check-maven:check` only if the plugin is already configured in `pom.xml` | `pom.xml` | Otherwise «not checked»; the plugin download is an install |
| Containers | `trivy --version` / `grype --version` | `trivy fs --scanners vuln,secret .` / `grype dir:.` | lockfiles and image layers | Read-only by default; never `--fix` |
| Secrets in history | `gitleaks version` / `trufflehog --version` | `gitleaks detect --no-banner --redact` / `trufflehog git file://. --only-verified` | the git history | `--redact` keeps the secret out of the review; a hit means «rotate», not just «remove» |
| GitHub Actions | `actionlint -version` | `actionlint` | `.github/workflows/*.yml` | Syntax and some security rules; `zizmor` if present for the security-specific audit |

## When nothing is installed

A grep is not an audit, but two things can still be checked by reading:

- The lockfile exists and is in step with the manifest (a manifest change without a lockfile
  change in the same diff is finding 26 in `catalog.md`).
- The bumped versions are pinned, not ranges, where the project pins.

Then the summary says, per tool: `npm audit — not available`, `gitleaks — not installed`. The
reader decides whether to run them; the review does not pretend.

## Reporting shape

```text
Audit tools run: composer audit — 0 advisories; npm audit --omit=dev — 2 high (lodash, minimist, both transitive via build tooling); govulncheck — not applicable; gitleaks — not installed
```

A non-zero count is one finding per advisory family with the tool's own identifier, the affected
package and version, the fixed version the tool names, and whether the dependency is production
or development.
