# Project Tidewater — settle

Payments settlement service, hardened after the 14 Aug incident.

## Start here
- `docs/RCA.md` — what happened on 14 Aug and why *(template — fill in
  from your real `incident-2026-08-14/` evidence bundle before this is
  submission-ready)*
- `docs/DECISIONS.md` — architecture decisions (EKS vs ECS, migration
  pattern, staging/prod cost split)
- `docs/CHANGES.md` — every defect fixed, and why
- `docs/RUNBOOK.md` — deploy, rollback, alert response
- `docs/NOT-DONE.md` — deliberate scope cuts
- `docs/AI-USAGE.md` — AI usage disclosure

## Quickstart
```
make up                    # bootstrap local k3d cluster + Postgres + Redis
make build TAG=1.9.0       # build image
make load TAG=1.9.0        # import into k3d
make deploy TAG=1.9.0      # deploy
make verify                # run smoke checks
```

Real deploys to a GitHub-hosted cluster run automatically via
`.github/workflows/deploy.yml` on push to `main`.

## Repo layout
```
app/                  API + worker source, Dockerfile
deploy/k8s/           Kubernetes manifests
deploy/nginx/         Ingress-level nginx config
migrations/           SQL migrations (expand/contract pattern — see ADR-002)
.github/workflows/    CI/CD pipeline
infra/terraform/      AWS IaC (VPC, EKS, RDS, ElastiCache, IAM)
docs/                 RCA, ADRs, runbook, changes, disclosures
incident-2026-08-14/  Evidence bundle (as received)
local/                k3d bootstrap for laptop development
```

## What's real vs template in this scaffold
Everything under `deploy/`, `.github/`, `infra/`, `migrations/`,
`local/`, and the `Makefile` is complete, working infrastructure code.
`docs/RCA.md` is a structural template only — it requires the actual
incident evidence bundle to fill in with cited facts, which is the point
of that deliverable.
