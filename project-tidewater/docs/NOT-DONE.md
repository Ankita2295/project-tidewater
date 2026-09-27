# Not Done

In priority order — what I'd do next with two more weeks.

1. **PgBouncer in front of Postgres.** The current connection budget
   (`deploy/k8s/hpa.yaml`) caps `maxReplicas` at 6 to stay under
   `max_connections`. That's a ceiling on horizontal scaling that
   shouldn't exist. A transaction-pooling PgBouncer would decouple pod
   count from raw connection count and let the HPA scale on real load
   instead of a DB-imposed limit.

2. **cosign image signing + admission-time verification** (Task F).
   Scanning catches known CVEs at build time; signing + admission
   control would guarantee only images that passed CI can ever run in
   the cluster, closing the gap where someone could `kubectl apply` an
   unscanned image directly.

3. **`make chaos-db` latency injection target** (Task F). Would prove
   the readiness/liveness split actually behaves as designed under a
   slow-but-not-down Postgres, rather than relying on the design
   argument alone.

4. **DR / AZ-failover drill environment.** Staging is deliberately
   single-AZ/single-NAT to hit the $250/mo budget (ADR-003), which
   means AZ-failure behavior is never actually exercised anywhere except
   prod. A short-lived, spun-up-on-demand environment for failover
   drills would close that gap without paying for it permanently.

5. **Automated contract-migration safety check in CI.** Right now
   nothing stops someone running a `*_contract.sql` migration too early
   (before the old code path is fully retired) other than the release
   sequence documented in ADR-002. A CI check that verifies no running
   revision still references a column a pending contract migration would
   drop is worth building.

6. **Full LocalStack plan for the Terraform** (bonus, not required).
   Would let `terraform plan` be exercised in CI without a real AWS
   account, catching more classes of config error than static
   scanning alone.

7. **Sealed-secrets or External Secrets Operator wired up end-to-end**
   in the local k3d cluster, not just the AWS path. Currently `make up`
   injects local secrets from a git-ignored `.env`, which is fine for a
   laptop but doesn't exercise the same secret-delivery mechanism prod
   uses, so it's not a full integration test of that path.
