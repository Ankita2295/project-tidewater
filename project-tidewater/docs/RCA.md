# RCA: 14 Aug production incident — v1.8.0 deploy

> **This file is a structural template.** Every bracketed placeholder
> below must be filled in from the real `incident-2026-08-14/` evidence
> bundle, with a file + line/timestamp citation for every factual claim.
> Do not fill this in from assumption or pattern-matching to "typical"
> incidents — the brief grades this on cited evidence, not plausibility.

## Summary
[One paragraph: what broke, for how long, customer/business impact.]

## Timeline (UTC, to the minute where evidence allows)
| Time | Event | Evidence |
|---|---|---|
| 14:02 | v1.8.0 deploy started | `incident-2026-08-14/ci-run.log:L__` |
| 14:05 | First 502s observed | `incident-2026-08-14/nginx-access.log:L__` |
| ... | ... | ... |
| 14:51 | Manual rollback completed, errors stop | `incident-2026-08-14/____:L__` |

## Root cause(s)
[State the primary mechanical cause, with evidence citations. Show any
capacity arithmetic explicitly, e.g.:
`replicas × workers_per_pod × conns_per_worker` vs `max_connections`,
using the actual replica count from `kubectl describe`/HPA evidence at
the time, not the current hardened config.]

## Contributing factors
[Secondary factors that made the primary cause worse or harder to
detect/recover from — e.g. probe configuration, log volume, alerting
gaps. Cite evidence for each.]

## How merchants came to be paid twice
[Trace the exact mechanism using worker log evidence — job IDs,
timestamps of pod termination vs job completion, any redelivery
evidence from Redis/worker logs. This needs to be airtight since it's
the highest-impact part of the incident.]

## Ruled out
[List anything in the evidence bundle that looked alarming but you
concluded was not causal, with the reasoning. E.g. "DiskPressure at
14:1_ — ruled out as a root cause of the initial 502s because the 502s
began at 14:05, before DiskPressure was reported at 14:1_ per
`node-dmesg.log:L__`; more likely a downstream symptom of X logging in
a restart loop."]

## Action items
| Action | Owner (role) | Priority | Status |
|---|---|---|---|
| Split liveness/readiness probes | Platform on-call | P0 | Done — see `docs/CHANGES.md` |
| Document + enforce DB connection budget in HPA | Platform on-call | P0 | Done — see `deploy/k8s/hpa.yaml` |
| Expand/contract migration pattern | Backend | P0 | Done — see `docs/DECISIONS.md` ADR-002 |
| Idempotency key on bank API calls | Backend | P0 | [confirm against real app code] |
| Post-deploy automatic verification + rollback | Platform on-call | P0 | Done — see `.github/workflows/deploy.yml` |
| Settlement-freshness SLO + alert | Platform on-call | P1 | Done — see `docs/RUNBOOK.md` |
| [fill in any additional items the real evidence surfaces] | | | |
