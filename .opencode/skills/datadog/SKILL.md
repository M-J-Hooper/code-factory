---
name: datadog
description: >
  Use when the user needs to query, investigate, or interact with any Datadog product.
  This includes APM traces, logs, metrics, monitors, error tracking, RUM, network monitoring,
  infrastructure hosts, Kubernetes data, security signals, incidents, SLOs, dashboards,
  synthetics, CI/CD visibility, service catalog, events, cost analysis, cloud integrations,
  fleet automation, and any other Datadog API domain. Also use when the user mentions
  "Datadog", "pup", service performance, observability data, production monitoring,
  alerting, or when they want to look up anything that Datadog tracks.
  Triggers: "check logs", "query metrics", "APM traces", "error tracking", "monitors",
  "Datadog", "pup", "service health", "latency", "error rate", "RUM sessions",
  "network flows", "security signals", "incidents", "SLOs", "dashboards", "synthetics",
  "infrastructure", "hosts", "Kubernetes", "CI/CD pipeline", "audit logs", "cost",
  "fleet", "on-call", "service catalog", "observability".
argument-hint: "[query or product domain]"
user-invocable: true
allowed-tools: Bash(pup:*), Bash(jq:*)
---

# Datadog Product Query

Announce: "I'm using the /datadog skill to query Datadog via the pup CLI."

## Step 1: Verify Authentication

Before any query, verify pup is authenticated:

```bash
pup auth status
```

If not authenticated, instruct the user to run `pup auth login` and wait for them to complete it.
Do not proceed until authentication is confirmed.

## Step 2: Classify Intent

Determine which pup domain the user's request maps to.
Many requests span multiple domains — start with the most specific one and chain queries as needed.

| User Intent | Primary Domain | Secondary |
|-|-|
| Service performance, latency, throughput | `apm` | `traces`, `metrics` |
| Application errors, exceptions, stack traces | `error-tracking` | `logs`, `traces` |
| Log search, log patterns, log volume | `logs` | `metrics` (for log-based metrics) |
| Custom metrics, system metrics, graphing | `metrics` | `dashboards` |
| Alert status, monitor health, notifications | `monitors` | `downtime`, `slos` |
| APM spans, distributed traces, flame graphs | `traces` | `apm` |
| Frontend performance, user sessions, page loads | `rum` | `synthetics` |
| Network traffic, DNS, TCP, device monitoring | `network` | `infrastructure` |
| Host inventory, containers, processes | `infrastructure` | `fleet`, `tags` |
| Security findings, threat detection, compliance | `security` | `audit-logs` |
| Incident management, postmortems | `incidents` | `cases`, `on-call` |
| SLO status, error budgets | `slos` | `monitors` |
| Synthetic tests, uptime checks | `synthetics` | `monitors` |
| CI/CD pipelines, test results, flaky tests | `cicd` | `code-coverage` |
| Service ownership, metadata, dependencies | `service-catalog` | `apm`, `scorecards` |
| Dashboard management | `dashboards` | `notebooks` |
| Cost analysis, billing, usage | `cost` | `usage` |
| Cloud integrations (AWS, GCP, Azure) | `cloud` | `infrastructure` |
| Fleet automation, agent management | `fleet` | `infrastructure` |
| Event stream, audit trail | `events` | `audit-logs` |
| On-call schedules, team management | `on-call` | `incidents` |
| Change tracking, deployment events | `change-requests` | `events` |
| Observability pipelines | `obs-pipelines` | `logs` |
| AI investigations | `investigations` | `logs`, `traces` |

## Step 3: Execute Query

Always use `--agent` flag — pup auto-detects AI assistants but being explicit avoids edge cases.
Always use JSON output (the default) for structured parsing.

### Query Syntax Reference

**Logs**: `status:error`, `service:web-app`, `@attr:val`, `host:i-*`, `"exact phrase"`, `AND/OR/NOT` operators, `-status:info` (negation), wildcards with `*`.

**Metrics**: `<aggregation>:<metric_name>{<filter>} by {<group>}`.
Example: `avg:system.cpu.user{env:prod} by {host}`.
Aggregations: `avg`, `sum`, `min`, `max`, `count`.

**APM/Traces**: `service:<name> resource_name:<path> @duration:>5000000000 status:error operation_name:<op>`.
Durations are always in **nanoseconds**: 1 second = 1,000,000,000 ns, 5ms = 5,000,000 ns.

**RUM**: `@type:error @session.type:user @view.url_path:/checkout @action.type:click service:<app-name>`.

**Security**: `@workflow.rule.type:log_detection source:cloudtrail @network.client.ip:10.0.0.0/8 status:critical`.

**Events**: `sources:nagios,pagerduty status:error priority:normal tags:env:prod`.

**Monitors**: Use `--name` for substring search, `--tags` for tag filtering (comma-separated). Use `--query` with `pup monitors search` for full-text search.

### Time Ranges

Always specify `--from` explicitly. Relative formats: `5s`, `30m`, `1h`, `4h`, `1d`, `7d`, `30d`.
Start narrow (1h) and widen only if needed — large ranges are slow and expensive.

### Common Query Patterns

**Investigate a service:**
```bash
pup apm services --agent
pup traces search --query "service:<name>" --from 1h --limit 10 --agent
pup logs search --query "service:<name> status:error" --from 1h --limit 20 --agent
pup error-tracking issues --query "service:<name>" --from 1d --agent
```

**Check monitor health:**
```bash
pup monitors list --tags "service:<name>" --agent
pup monitors search --query "<monitor-name>" --agent
```

**Metrics investigation:**
```bash
pup metrics search --query "<metric-name>" --agent
pup metrics query --query "avg:<metric>{env:prod} by {host}" --from 1h --agent
```

**Log analysis (prefer aggregation over raw search):**
```bash
pup logs aggregate --query "service:<name> status:error" --compute count --from 1h --agent
pup logs search --query "service:<name> status:error" --from 1h --limit 20 --agent
```

**Infrastructure:**
```bash
pup infrastructure hosts --filter "availability-zone:us-east-1a" --agent
pup tags list --agent
```

**Incidents and on-call:**
```bash
pup incidents list --agent
pup on-call teams --agent
```

**CI/CD visibility:**
```bash
pup cicd pipelines --from 1d --agent
pup cicd flaky-tests --from 7d --agent
pup cicd tests --from 1d --agent
```

**SLOs:**
```bash
pup slos list --agent
pup slos status --id <slo-id> --agent
```

**Security:**
```bash
pup security signals --query "status:critical" --from 1d --agent
pup security findings --from 1d --agent
```

**Service catalog:**
```bash
pup service-catalog list --agent
pup service-catalog get --service <name> --agent
```

**Network monitoring:**
```bash
pup network flows --from 1h --agent
pup network devices --agent
```

**RUM:**
```bash
pup rum events --query "@type:error" --from 1h --agent
pup rum sessions --from 1h --agent
```

**Synthetics:**
```bash
pup synthetics tests --agent
pup synthetics suites --agent
```

**Cost and usage:**
```bash
pup cost attribution --from 30d --agent
pup usage summary --from 30d --agent
```

**Dashboards:**
```bash
pup dashboards list --agent
pup dashboards get --id <dashboard-id> --agent
```

## Step 4: Interpret and Follow Up

After each query:

1. **Summarize findings** in plain language — surface the signal, not the raw JSON.
2. **Identify patterns** — recurring errors, latency spikes, anomalies.
3. **Suggest next queries** — if logs show errors, offer to check traces for the same timeframe. If a monitor is alerting, offer to check the underlying metric.
4. **Cross-reference domains** — chain queries across domains to build a complete picture.

When the user is investigating an issue, follow a natural diagnostic flow:
monitors → metrics → traces → logs → error-tracking (narrowing from broad to specific).

## Best Practices

- Always specify `--from` to set a time range; most commands default to 1h but be explicit.
- Start with narrow time ranges (1h) then widen if needed.
- Filter by service first when investigating: `--query='service:<name>'`.
- Use `--limit` to control result size; default varies by command (50-200).
- For monitors, use `--tags` to filter rather than listing all and parsing locally.
- Use `pup logs aggregate` for counts and distributions instead of fetching all logs and counting locally.
- Chain narrow queries: first aggregate to find patterns, then search for specific examples.
- Use `pup monitors search` for full-text search, `pup monitors list` for tag/name filtering.

## Anti-Patterns

These are common mistakes that waste time or produce wrong results:

- Do not omit `--from` on time-series queries — you will get unexpected time ranges or errors.
- Do not use `--limit=1000` as a first step — start small and refine.
- Do not list all monitors/logs without filters in large orgs (>10k monitors).
- APM durations are in **nanoseconds**, not seconds or milliseconds.
- Do not fetch raw logs to count them — use `pup logs aggregate --compute=count`.
- Do not use `--from=30d` unless you specifically need a month of data.
- Do not retry failed requests without checking the error: 401 means re-authenticate, 403 means missing permissions.
- Do not use `pup metrics query` without specifying an aggregation.
- Do not pipe large JSON through multiple jq transforms — use query filters at the API level.

## Error Handling

| Error | Action |
|-|-|
| `pup` not found | Tell user to install: check internal docs for installation instructions |
| 401 Unauthorized | Run `pup auth login` to re-authenticate |
| 403 Forbidden | User lacks permissions for this API; suggest checking role assignments |
| 429 Rate Limited | Wait and retry with a narrower query or smaller `--limit` |
| Empty results | Widen time range, check query syntax, verify service/tag names exist |
| Timeout on large queries | Narrow the time range or add more filters |
| Auth session expired | Run `pup auth refresh` or `pup auth login` |
