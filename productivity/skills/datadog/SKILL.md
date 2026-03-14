---
name: datadog
description: >
  Use when the user needs to query, investigate, or interact with any Datadog product
  via the pup CLI. Covers APM, traces, logs, metrics, monitors, error tracking, RUM,
  network, infrastructure, security, incidents, SLOs, synthetics, CI/CD, service catalog,
  dashboards, cost, cloud integrations, fleet, and 30+ other API domains.
  Triggers: "check logs", "query metrics", "APM traces", "error tracking", "monitors",
  "Datadog", "pup", "service health", "latency", "error rate", "RUM sessions",
  "network flows", "security signals", "incidents", "SLOs", "synthetics",
  "infrastructure", "hosts", "Kubernetes", "CI/CD pipeline", "observability".
argument-hint: "[query or product domain]"
user-invocable: true
allowed-tools: Bash(pup:*), Bash(jq:*)
---

# Datadog Product Query

Announce: "I'm using the /datadog skill to query Datadog via the pup CLI."

## Step 1: Verify Authentication

```bash
pup auth status --agent
```

If not authenticated, instruct the user to run `pup auth login` and wait for confirmation.

For multi-org setups, use `--org <name>` on all commands to target the correct organization.

## Step 2: Discover Commands

pup is self-documenting. When unsure about a domain's subcommands or flags:

```bash
pup <domain> --help --agent
```

This returns structured JSON with every subcommand, flag, type, and default.
Use this as the primary reference — the patterns below cover common workflows,
but `pup --help` is the authoritative source for any domain.

## Step 3: Classify Intent and Execute

Determine which pup domain the user's request maps to.
Many requests span multiple domains — start with the most specific, then chain.

| User Intent | Primary | Chain With |
|-|-|-|
| Service performance, latency, throughput | `apm` | `traces`, `metrics` |
| Application errors, exceptions, stack traces | `error-tracking` | `logs`, `traces` |
| Log search, patterns, volume | `logs` | `metrics` |
| Custom or system metrics | `metrics` | `dashboards` |
| Alert status, monitor health | `monitors` | `downtime`, `slos` |
| Distributed traces, spans | `traces` | `apm` |
| Frontend performance, user sessions | `rum` | `synthetics` |
| Network traffic, device monitoring | `network` | `infrastructure` |
| Host inventory, containers | `infrastructure` | `fleet`, `tags` |
| Security findings, threat detection | `security` | `audit-logs` |
| Incident management | `incidents` | `cases`, `on-call` |
| SLO status, error budgets | `slos` | `monitors` |
| Synthetic tests, uptime | `synthetics` | `monitors` |
| CI/CD pipelines, flaky tests | `cicd` | `code-coverage` |
| Service ownership, metadata | `service-catalog` | `scorecards` |
| Cost analysis, billing | `cost` | `usage` |
| Cloud integrations | `cloud` | `infrastructure` |

For ready-to-use command patterns per domain, see [references/query-patterns.md](references/query-patterns.md).

### Global Flags

| Flag | Purpose |
|-|-|
| `--agent` | Always include. Enables structured output for AI assistants. |
| `--from <range>` | Time range. Always specify explicitly. Formats: `1h`, `30m`, `7d`, `2hours`. |
| `--limit <n>` | Result cap. Start small (10-50), increase only if needed. |
| `--output table` | Human-readable display. Default is JSON (better for parsing). |
| `--read-only` | Block all write operations. Use when investigating to prevent accidental changes. |
| `--org <name>` | Target a specific org in multi-org setups. |

### Query Syntax

**Logs**: `status:error service:web-app @attr:val host:i-* "exact phrase"`.
Operators: `AND`, `OR`, `NOT`, `-field:val` (negation), `*` (wildcard).

**Metrics**: `<agg>:<metric>{<filter>} by {<group>}`.
Example: `avg:system.cpu.user{env:prod} by {host}`.
Aggregations: `avg`, `sum`, `min`, `max`, `count`.

**Traces**: `service:<name> resource_name:<path> @duration:>5s status:error`.
Duration supports shorthand (`5s`, `500ms`) and raw nanoseconds (`5000000000`).

**RUM**: `@type:error @session.type:user @view.url_path:/path service:<app>`.

**Monitors**: `--name` for substring, `--tags` for tag filter, `--query` for full-text search.

## Step 4: Investigation Workflows

When diagnosing issues, follow a structured flow rather than ad-hoc queries.

### Service Degradation

1. `pup monitors list --tags "service:<name>"` — check alerting monitors
2. `pup metrics query --query "avg:<key_metric>{service:<name>}" --from 1h` — identify anomaly timing
3. `pup traces search --query "service:<name> @duration:>1s" --from 1h --limit 10` — find slow traces
4. `pup logs search --query "service:<name> status:error" --from 1h --limit 20` — correlate with errors
5. `pup apm dependencies --service <name>` — check downstream dependencies

### Error Spike

1. `pup logs aggregate --query "service:<name>" --compute count --group-by status --from 4h` — quantify the spike
2. `pup error-tracking issues --query "service:<name>" --from 1d` — group by error type
3. `pup traces search --query "service:<name> status:error" --from 1h --limit 10` — get trace-level detail
4. `pup events search --from 4h` — check for deploy or change events correlating with the spike

### Infrastructure Issue

1. `pup infrastructure hosts --filter "service:<name>"` — identify affected hosts
2. `pup metrics query --query "avg:system.cpu.user{host:<name>}" --from 1h` — check resource utilization
3. `pup network flows --from 1h` — check network health
4. `pup fleet agents` — verify agent status

After each query, summarize findings in plain language, identify patterns, and suggest next queries.
Chain narrow queries: aggregate first to find patterns, then search for specific examples.

## Step 5: Critical Gotchas

These are the mistakes that waste the most time. pup's own `--help` covers general usage;
this section covers what agents specifically get wrong.

| Gotcha | Detail |
|-|-|
| Missing `--from` | Most commands default to 1h but some don't. Always specify `--from` explicitly. |
| Huge result sets | Never start with `--limit=1000`. Start with 10-50, refine query, then increase. |
| Counting via raw fetch | Do not fetch all logs and count them locally. Use `pup logs aggregate --compute count`. |
| Duration units | APM durations in raw form are **nanoseconds**: 1s = 1,000,000,000 ns. Prefer shorthand: `@duration:>5s`. |
| Missing aggregation | `pup metrics query` requires an aggregation prefix: `avg:`, `sum:`, `max:`, `min:`, `count:`. |
| Auth errors | 401 = re-authenticate (`pup auth login`). 403 = missing permissions. Do not blindly retry. |
| Wide time ranges | `--from=30d` is slow. Start narrow (1h), widen only if needed. |
| Large org listings | Do not list all monitors or logs unfiltered in large orgs. Always add `--tags` or `--query` filters. |

## Error Handling

| Error | Action |
|-|-|
| `pup` not found | Tell user to install pup (check internal Datadog docs) |
| 401 Unauthorized | `pup auth login` to re-authenticate |
| 403 Forbidden | User lacks API permissions; check role assignments |
| 429 Rate Limited | Narrow query scope: smaller `--limit`, tighter time range, add filters |
| Empty results | Widen time range, verify service/tag names with `pup service-catalog list` |
| Timeout | Narrow `--from` range or add more query filters |
| Auth expired | `pup auth refresh` or `pup auth login` |
| Unknown domain | Run `pup --help` to list all available domains |
