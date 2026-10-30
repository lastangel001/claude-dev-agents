# False Positives — what is not a finding

Each entry is a known trap: a pattern match that looks like a defect and is not. Skip these, and
when one is borderline, say which evidence puts it on the safe side.

## Skip list

- **Example and template files**: `.env.example`, `config.sample.yml`, `settings.dist.php` with
  placeholder values (`changeme`, `xxx`, `your-key-here`, `test-key-123`). A finding only if the
  value is real (it has the shape and entropy of a live key, or a grep of history shows it was
  used).
- **Fixtures, seeds and test credentials** in test directories, clearly marked, not valid anywhere
  (`password` for a seeded dev user, a self-signed cert in `tests/fixtures/`). A finding if the
  seed runs in production or the credential is reused there.
- **Public keys and publishable keys** meant to be public: a Stripe `pk_`, a Mapbox token with
  referrer restrictions, an OAuth client id, a JWT public key. The matching secret key is the
  finding.
- **Checksums and cache keys**: SHA-256 or MD5 for deduplication, ETags, content addressing,
  cache keys, integrity checks. A finding only when the hash protects a password or a signature.
- **Framework defaults that already escape or parameterise**: `{{ }}` in Blade and Jinja2 with
  autoescape on, Vue text interpolation, Eloquent and Django ORM bindings, Prisma tagged
  templates. Name the framework and version and check the diff did not opt out (`{!! !!}`,
  `|safe`, `mark_safe`, `v-html`, `$queryRawUnsafe`, `autoescape false`).
- **Internal-only services** behind a verified boundary: say which evidence establishes it (the
  ingress config, the NetworkPolicy, the brief's deployment context), not an assumption from the
  service's name.
- **Randomness that gates nothing**: `Math.random()` for a UI animation, `random.choice` for a
  test fixture, a shuffle in a non-security feature.
- **`verify=False` in a test** against a local mock with a self-signed cert, inside the test
  directory, not in a client class the application imports.
- **A query the language reviewer already reported**: cite its id and go beyond (the missing
  tenant filter the parameterisation does not fix); do not re-report it.
- **A dependency advisory the audit tool marks as not reachable** (`govulncheck` symbol
  analysis, `npm audit` on a dev-only dependency with `--omit=dev`): report it as information
  with the tool's verdict, not as a finding at the advisory's CVSS word.

## The reachable-path rule

A finding needs a concrete input or state, from a named entry point, that arrives at the defect:

- **Entry point**: the route, consumer, cron job or webhook, by name or path.
- **Identity**: anonymous, any authenticated user, a user of another tenant, an admin.
- **Input or state**: the request field, the file, the row, the environment variable.
- **Outcome**: what the attacker reads, writes, runs or bypasses.

«Could be dangerous» without the path goes to the review's `Unverified assumptions` with the
experiment that settles it: a request to send, a config to read, a log to grep, a route table to
list. `review-verifier` marks a finding without the path `UNPROVEN`, and an author who reads two
UNPROVEN findings stops reading the third.

## Consolidation

One finding per pattern per access model, not per occurrence. Twelve concatenated queries in one
repository class are one finding with twelve locations; the same pattern in a second language or
on a second boundary is a second finding.

## Zero findings

Zero findings on a trigger-touching diff is a valid review when every family that the diff
touches was walked and the summary says so, and when the audit tools that ran (or did not) are
named. A clean table without those two lines is not a clean review; it is an unchecked one.
