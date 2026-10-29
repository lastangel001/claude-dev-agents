# Observability Patterns

Instrumentation ships with the service, not after the first incident. Names and figures below are
invented.

## The Three Signals

| Signal | Answers | Shape | Transport |
|---|---|---|---|
| **Metrics** | how much, how fast, how often | numbers over time, low cardinality | Prometheus scrape of `/metrics` (OpenMetrics); push only for batch jobs (Pushgateway) |
| **Logs** | what happened in this request | structured events, high cardinality | stdout → the platform's collector (Fluent Bit, Vector, Promtail) → Loki / Elasticsearch / cloud |
| **Traces** | where the time went across services | spans with parent ids | OpenTelemetry SDK → OTel Collector → Tempo / Jaeger / cloud APM |

Logs to stdout only; a file inside a container is lost with the pod and fills the node's disk
first. Metrics and traces leave through the same OpenTelemetry Collector where the stack has one,
so the exporter is configured once per cluster, not per service.

## Structured Logs with Correlation Ids

```json
{"ts":"2026-04-12T09:14:03.218Z","level":"error","service":"ledger-api","version":"2.14.0",
 "trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","request_id":"c7e1…","user_id":"u_48213",
 "route":"POST /api/v1/invoices","status":500,"duration_ms":412,
 "msg":"invoice total mismatch","invoice_id":"inv_90177","expected":12400,"actual":12350}
```

One JSON object per line; fixed keys (`ts`, `level`, `service`, `version`, `trace_id`,
`request_id`, `msg`) plus event-specific fields; no string interpolation into `msg`. The request
id is accepted from the `X-Request-Id` header or generated at the edge and passed to every
downstream call, queue message and log line; with tracing enabled, `trace_id` from the active span
is the correlation id and the logs link to the trace. Log level per environment via config, not a
rebuild; `debug` off in production by default.

## What to Never Log

Passwords, tokens, API keys, session cookies, `Authorization` headers, full card numbers, bank
account numbers, government ids, one-time codes, private keys, full request bodies of auth
endpoints, full database connection strings. Redact at the logger (a denylist of keys, a filter
on the `Authorization` header), not by hoping the developer remembers; the test suite asserts the
redaction. Personal data that must be logged (an email as the user identifier) gets a retention
that matches the privacy policy and a hashed id where a hash is enough.

## Metrics Naming

Prometheus conventions: `snake_case`, a unit suffix (`_seconds`, `_bytes`, `_total` for counters),
base units (seconds not milliseconds, bytes not megabytes), the namespace first:
`ledger_invoice_created_total`, `http_request_duration_seconds`, `queue_depth`. Labels are
dimensions you will group by (`route`, `method`, `status_class`, `queue`); never a user id, an
invoice id, an email, a raw URL with ids in it: cardinality grows without bound and the TSDB
falls over. Histograms for latency with buckets that bracket the SLO (`0.05, 0.1, 0.25, 0.5, 1, 2.5`),
not the default set. Every service exposes `build_info{version="2.14.0", commit="…"} 1`.

## RED and USE

**RED** for every request-driven service (API, worker consuming a queue):

- **Rate** `sum(rate(http_requests_total[5m])) by (route)`
- **Errors** `sum(rate(http_requests_total{status_class="5xx"}[5m])) / sum(rate(http_requests_total[5m]))`
- **Duration** `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, route))`

**USE** for every resource (node, database, queue, connection pool):

- **Utilisation** share of time busy (CPU, pool connections in use / pool size)
- **Saturation** work waiting (run-queue length, queue depth, pool wait time)
- **Errors** failed operations (disk errors, connection refusals)

RED tells you whether users are affected; USE tells you why. Alerts come from RED; USE goes on the
dashboard and into the capacity review.

## SLOs and Error Budgets

An SLO is a target over a window on a user-facing indicator: «99.5 % of `POST /invoices` requests
succeed within 500 ms over 30 days». The error budget is the complement (0.5 % of requests, roughly
3.6 hours of full outage per month). Budget left decides the pace: plenty → ship; nearly spent →
reliability work and a stricter canary; spent → freeze features until it recovers. Start with two
or three SLOs per service (availability and latency of the main flows), measured from the edge,
not from inside the pod.

## Alerts on Symptoms, with Runbook Links

```yaml
groups:
  - name: ledger-api
    rules:
      - alert: LedgerApiHighErrorRate
        expr: |
          sum(rate(http_requests_total{service="ledger-api",status_class="5xx"}[5m]))
            / sum(rate(http_requests_total{service="ledger-api"}[5m])) > 0.02
        for: 5m
        labels: { severity: page, team: ledger }
        annotations:
          summary: "ledger-api 5xx rate {{ $value | humanizePercentage }} for 5m"
          runbook_url: https://runbooks.example.test/ledger-api/high-error-rate
      - alert: LedgerApiErrorBudgetBurn
        expr: ledger_api:slo_error_ratio:rate1h > 14.4 * 0.005 and ledger_api:slo_error_ratio:rate5m > 14.4 * 0.005
        for: 2m
        labels: { severity: page, team: ledger }
        annotations: { runbook_url: https://runbooks.example.test/ledger-api/error-budget }
```

Rules: a page means a human must act now; everything else is a ticket or a panel. `for:` long
enough to skip a single scrape blip. Every alert has a runbook with: what the alert means, how to
confirm, the three most likely causes with the query for each, the mitigation, who to escalate to.
Multi-window burn-rate alerts (fast 5m/1h, slow 6h/3d) replace static thresholds once an SLO
exists. No alerts on CPU, memory, disk below 80 %, a single pod restart, or anything the autoscaler
or the orchestrator fixes by itself; those are dashboard panels and capacity tickets.

## Dashboards per Service

One dashboard per service, same layout everywhere so an on-call engineer who has never seen the
service finds the row: top row RED for the service as a whole; second row RED per route or
queue; third row USE for its dependencies (database pool, cache hit ratio, queue depth); fourth
row deploy markers, replica count, restarts, version. Dashboards as code (Grafana JSON or
jsonnet/grafanalib in the repo, provisioned by the pipeline); a dashboard edited in the UI and
never exported is lost on the next provisioning run.

## Tracing Basics

OpenTelemetry auto-instrumentation for the framework and the HTTP/DB clients gives the span tree
for free; manual spans for the business steps that matter (`invoice.compute_totals`). W3C
`traceparent` propagated through HTTP headers and queue message headers so a trace crosses the
worker. Sampling head-based at 1–10 % in production with 100 % for errors where the collector
supports tail sampling; 100 % in staging. Span attributes follow the semantic conventions
(`http.route`, `db.system`) and never carry secrets or personal data, same rule as logs.

## Log Retention and Cost

Volume is the cost driver: per-request `info` logs at 2 000 req/s are about 170 million lines a
day. Levers in order: sample or drop the noisy `info` lines at the collector (health checks,
readiness probes, static assets), shorten retention per stream (7 days hot for `debug`/`info`,
30–90 days for `warn`/`error` and audit), move audit logs to cheap object storage with a longer
retention, cap label cardinality in Loki. Retention is a policy decided with the owners of the data
(legal, security), written down, and enforced by the platform, not by a disk filling up.

## Anti-patterns

- Logs to a file in the container; `print` statements instead of the logger.
- Interpolated log messages (`"user " + id + " failed"`) that nothing can filter on.
- Secrets or tokens in logs, span attributes or metric labels.
- A metric label with a user id or a URL containing an id.
- Latency as an average; a histogram with the default buckets when the SLO is 300 ms.
- Alerts on CPU, memory or «pod restarted»; alerts without `for:`; alerts without a runbook.
- A dashboard per person instead of per service; a dashboard that lives only in the UI.
- Traces that stop at the queue because the message carries no `traceparent`.
