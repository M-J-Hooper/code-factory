# Query Patterns by Domain

Ready-to-use command patterns for common Datadog investigations.
For domains not listed here, run `pup <domain> --help` to discover subcommands and flags.

## Service Investigation

```bash
pup apm services --agent
pup apm dependencies --service <name> --agent
pup traces search --query "service:<name>" --from 1h --limit 10 --agent
pup traces aggregate --query "service:<name>" --from 1h --agent
pup logs search --query "service:<name> status:error" --from 1h --limit 20 --agent
pup logs aggregate --query "service:<name> status:error" --compute count --from 1h --agent
pup error-tracking issues --query "service:<name>" --from 1d --agent
pup service-catalog get --service <name> --agent
```

## Monitors and Alerting

```bash
pup monitors list --tags "service:<name>" --agent
pup monitors search --query "<monitor-name>" --agent
pup monitors get --id <monitor-id> --agent
pup downtime list --agent
pup slos list --agent
pup slos status --id <slo-id> --agent
```

## Metrics

```bash
pup metrics search --query "<metric-name>" --agent
pup metrics query --query "avg:<metric>{env:prod} by {host}" --from 1h --agent
pup metrics list --agent
pup metrics tags --metric <metric-name> --agent
```

## Logs

```bash
pup logs aggregate --query "service:<name> status:error" --compute count --from 1h --agent
pup logs search --query "service:<name> status:error" --from 1h --limit 20 --agent
pup logs aggregate --query "service:<name>" --compute count --group-by status --from 1h --agent
```

## Infrastructure

```bash
pup infrastructure hosts --filter "availability-zone:us-east-1a" --agent
pup infrastructure hosts --filter "service:<name>" --agent
pup tags list --agent
pup fleet agents --agent
```

## Security

```bash
pup security signals --query "status:critical" --from 1d --agent
pup security findings --from 1d --agent
pup security rules --agent
pup audit-logs search --from 1d --agent
```

## Incidents and On-Call

```bash
pup incidents list --agent
pup incidents get --id <incident-id> --agent
pup on-call teams --agent
pup cases search --agent
```

## CI/CD

```bash
pup cicd pipelines --from 1d --agent
pup cicd flaky-tests --from 7d --agent
pup cicd tests --from 1d --agent
pup code-coverage branch-summary --agent
```

## RUM and Synthetics

```bash
pup rum events --query "@type:error" --from 1h --agent
pup rum sessions --from 1h --agent
pup rum apps --agent
pup synthetics tests --agent
pup synthetics suites --agent
```

## Network

```bash
pup network flows --from 1h --agent
pup network devices --agent
pup network interfaces --agent
```

## Cost and Usage

```bash
pup cost attribution --from 30d --agent
pup cost by-org --from 30d --agent
pup usage summary --from 30d --agent
pup usage hourly --from 1d --agent
```

## Dashboards and Notebooks

```bash
pup dashboards list --agent
pup dashboards get --id <dashboard-id> --agent
pup notebooks list --agent
```

## Cloud Integrations

```bash
pup cloud aws --agent
pup cloud gcp --agent
pup cloud azure --agent
pup integrations list --agent
```
