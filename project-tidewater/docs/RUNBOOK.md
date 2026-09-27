# Runbook

## Deploy

Deploys run automatically on push to `main` via `.github/workflows/deploy.yml`:
lint/test → build (once) → scan → deploy → verify → auto-rollback on
verification failure.

Manual deploy of an already-built image (skips build):
```
gh workflow run deploy.yml -f image_tag=<12-char-sha>
```

## Manual rollback

The pipeline rolls back automatically on verification failure — this is
only for rolling back something that passed verification but is
misbehaving in a way the smoke checks didn't catch.

```
kubectl rollout undo deployment/settle-api
kubectl rollout undo deployment/settle-worker
kubectl rollout status deployment/settle-api --timeout=120s
```

Safe at any point because schema changes follow expand/contract
(see `docs/DECISIONS.md` ADR-002) — there is never a pending
down-migration blocking a rollback, **except** immediately after a
`*_contract.sql` migration has been run. Check `migrations/` for any
contract step applied in the last release before rolling back more than
one revision.

To check current vs previous revision:
```
kubectl rollout history deployment/settle-api
```

---

## Alert runbook entries

### Alert: `SettleAPIHighErrorRate`
**Fires when:** 5xx rate on `settle-api` > 5% over 5 minutes.
**SLO this protects:** Availability/latency SLO.
**Likely causes:** Bad deploy that passed CI verification but degrades
under real traffic; Postgres connection exhaustion (check `pg_stat_activity`
count against the budget documented in `deploy/k8s/hpa.yaml`); dependency
outage (mocked bank API).
**First actions:**
1. Check `kubectl get pods -l app=settle-api` for restart counts / crash loops.
2. Check Grafana `settle / API overview` dashboard for correlated
   latency and DB connection panels.
3. If tied to a recent deploy, roll back manually (see above) rather
   than waiting for investigation.

### Alert: `SettleAPIHighLatencyP95`
**Fires when:** p95 latency on non-`/reports/daily` routes > 1.5s for 5 minutes.
**SLO this protects:** Availability/latency SLO.
**First actions:**
1. Check DB connection saturation — this was the mechanism in the 14 Aug
   incident (see `docs/RCA.md`).
2. Check HPA current replica count vs max (6) — if pinned at max and
   still degrading, the connection budget itself needs revisiting, not
   just replica count.

### Alert: `SettlementProcessingStale`
**Fires when:** oldest `pending` settlement row older than 10 minutes.
**SLO this protects:** Settlement correctness/freshness SLO.
**Likely causes:** worker pods down/crashlooping; Redis unavailable;
queue backlog exceeding worker throughput.
**First actions:**
1. `kubectl get pods -l app=settle-worker` — confirm workers are running.
2. Check Redis queue depth in Grafana.
3. This is the alert class that would have caught the 14 Aug double-payment
   pattern earlier than the API error-rate alerts alone — treat any firing
   of this alert as higher priority than it looks, even if API-level
   metrics look fine.

### Alert: `SettleWorkerRestartLoop`
**Fires when:** any `settle-worker` pod restarts > 3 times in 15 minutes.
**SLO this protects:** Settlement correctness/freshness SLO.
**Likely causes:** unhandled exception in payout logic; OOM; SIGTERM
handling regression (see `deploy/k8s/deployment.yaml` termination grace
period notes) reintroducing the double-payment risk class.
**First actions:**
1. `kubectl logs <pod> --previous` for the crash reason.
2. If tied to a recent deploy, roll back immediately — this alert class
   is directly connected to the mechanism that caused the 14 Aug
   double-payment, treat with urgency.

### Alert: `NodeDiskPressure`
**Fires when:** any node reports `DiskPressure` condition.
**SLO this protects:** Availability/latency SLO (indirect — DiskPressure
can trigger eviction of healthy pods).
**Likely causes:** a service log-looping without rotation/limits (this
was present as a contributing factor on 14 Aug — see `docs/RCA.md`).
**First actions:**
1. `kubectl describe node <node>` for the specific pressure source.
2. Check for any container repeatedly restarting and writing to stdout
   in a tight loop — the container runtime's log driver has no size cap
   by default; confirm the log rotation config fix (see
   `docs/CHANGES.md`) is actually deployed on this node.
