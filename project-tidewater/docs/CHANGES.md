# Changes

Each entry: what was wrong, why it mattered, what changed. Cross-reference
with `docs/RCA.md` for the incident evidence that motivated each fix
(fill in citations there once you have the real evidence bundle).

## app/Dockerfile
- **Was:** ran as root, single-stage build with compiler toolchain in
  the final image, no resource/worker ceiling documented.
- **Why it mattered:** larger attack surface, harder to reason about
  the DB-connection budget math (Task B) if worker count isn't fixed
  and documented.
- **Fix:** multi-stage build, non-root user (uid 10001), `GUNICORN_WORKERS`
  fixed and referenced directly in the HPA connection-budget comment.

## deploy/k8s/deployment.yaml
- **Was:** one health endpoint used for both liveness and readiness,
  backed by a live DB ping.
- **Why it mattered:** when Postgres is slow, every pod fails the same
  check at once -> kubelet kills all of them simultaneously -> restart
  storm against an already-struggling database. This is the most likely
  mechanical explanation for the API pods entering a restart loop on 14
  Aug (verify against the real evidence bundle's timestamps/logs).
- **Fix:** split into `/livez` (process-alive only, no dependency calls)
  for liveness, and `/healthz` (DB check included) for readiness only.
  A slow DB now removes pods from Service endpoints without killing them.
- **Also fixed:** `maxUnavailable: 0` on rollout so capacity is never
  dropped mid-deploy; `terminationGracePeriodSeconds` raised and worker
  given a `preStop` drain window so in-flight jobs aren't killed
  mid-payout (the direct double-payment mechanism); added PDBs so
  voluntary disruptions can't take out too many pods at once; dropped
  root, added `readOnlyRootFilesystem` and capability drop.

## deploy/k8s/hpa.yaml
- **Was:** no documented relationship between `maxReplicas` and Postgres
  `max_connections = 100`.
- **Why it mattered:** without this arithmetic, autoscaling can quietly
  create more DB connections than Postgres allows, causing new
  connection attempts to fail/queue under load — exactly the kind of
  capacity failure implicated in the incident.
- **Fix:** `maxReplicas` capped at 6, with the full connection-budget
  formula documented inline in the file (see comment block).

## deploy/nginx/settle.conf
- **Was:** presumably one blanket timeout too short for
  `/reports/daily` (documented as 6-9s).
- **Why it mattered:** a legitimately slow-but-healthy request gets
  turned into a client-visible 504, inflating perceived error rate.
- **Fix:** per-location timeout override for `/reports/daily`; added
  request rate limiting that didn't exist before.

## migrations/0008.sql -> 0008a_expand.sql / 0008b_contract.sql
- **Was:** single in-place column rename + NOT NULL column addition,
  applied in lockstep with the code deploy.
- **Why it mattered:** breaks any v1.7 pod still serving traffic during
  the rolling update (reads/writes against a column that no longer
  exists under that name), and makes rollback require a down-migration.
- **Fix:** expand/contract split, detailed in `docs/DECISIONS.md` ADR-002.

## .github/workflows/deploy.yml
- **Was:** (per the brief, used for the incident deploy — presumed to
  rebuild per environment and/or lack a real post-deploy verification
  gate, since the incident reached production).
- **Fix:** build-once/promote-same-artifact, image scan before deploy,
  a verification stage that exercises real traffic (not just a readiness
  check) and checks pod restart count, and an automatic rollback job
  gated on verification failure — no manual action required.

## Secrets handling
- **Was:** Secret manifest present in the repo as received (brief notes
  "a Secret manifest" was included, implying real or placeholder values
  may have been committed).
- **Fix:** `deploy/k8s/config.yaml`'s Secret is explicitly a template
  with no real values; real values come from `local/.env` (git-ignored)
  for `make up`, or AWS Secrets Manager via IRSA-scoped IAM roles
  (`infra/terraform/modules/iam`) in AWS. CI references secrets only via
  `${{ secrets.* }}`, which GitHub Actions masks automatically in logs.
