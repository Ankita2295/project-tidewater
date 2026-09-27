# Architecture Decision Records

## ADR-001: EKS vs ECS/Fargate for compute

**Context**
Leadership wants a reviewed path to AWS this quarter. `settle` currently
runs on self-managed k8s; the team already writes k8s manifests, HPAs,
NetworkPolicies, and expects to keep doing so post-migration.

**Options considered**
1. **EKS** — managed control plane, self-/managed node groups (or
   Fargate profiles), full k8s API surface.
2. **ECS on Fargate** — no cluster/control plane to manage, no nodes to
   patch, simpler operational model, but a different (non-k8s) API and
   manifest format.

**Decision: EKS** (with managed node groups, Fargate left as an option
for low-traffic auxiliary jobs later, not the primary workload).

**Rationale**
- Zero migration cost for the existing `deploy/k8s/*.yaml` manifests,
  HPA, NetworkPolicy and PDB definitions — they run as-is.
- The team's operational muscle memory (`kubectl`, k8s-native
  observability tooling, k8s-native rollout/rollback semantics used in
  Task C) transfers directly.
- Fargate's per-pod billing and cold-start characteristics are a poor
  fit for a service with a slow endpoint (`/reports/daily`, 6-9s) and
  bursty worker queue depth — node-level bin-packing on EKS is cheaper
  at this workload's shape.

**Consequences**
- We own node patching/AMI upgrades (mitigated: managed node groups
  handle most of this).
- Slightly higher baseline cost than pure Fargate for very low, spiky
  traffic — not the case here given steady worker queue load.
- Requires the IRSA/OIDC setup in `modules/iam` for workload identity,
  which ECS's task roles would have given "for free" — accepted as the
  cost of k8s-native portability.

---

## ADR-002: Expand/contract migration pattern for schema changes

**Context**
The original `migrations/0008.sql` renamed a column in place during the
v1.8.0 rollout. Any v1.7 pod still serving traffic during the rolling
update read/wrote against the old column name and failed; a rollback to
v1.7 after the migration ran would have required a down-migration,
risking data loss for rows written under the new schema in the interim.

**Options considered**
1. Keep single-step destructive migrations, coordinate exact-cutover
   timing with a maintenance window.
2. **Expand/contract**: split every breaking schema change into an
   additive step (expand) that ships *before* the code that needs it,
   and a destructive step (contract) that ships only after the old code
   path is fully retired.

**Decision: expand/contract**, formalized as the standard pattern for
all future breaking schema changes to `settle`.

**Release sequence for this change:**
| Step | Action | Can v1.7 run? | Can v1.8 run? | Rollback needs down-migration? |
|---|---|---|---|---|
| 1 | Run `0008a_expand.sql` (additive) | Yes | Yes | N/A |
| 2 | Deploy v1.8 (dual-write, reads old col) | Yes (unaffected) | Yes | No |
| 3 | Deploy v1.8.1 (reads new col) | No | Yes | Rolls back to step 2, still no down-migration |
| 4 | Run `0008b_contract.sql` (drop old col) | No | Yes | Only irreversible step, run last, once stable |

**Consequences**
- Every breaking schema change now ships as (at minimum) two PRs/two
  releases instead of one — slower, deliberately.
- Rollback at any point before step 4 is a pure `kubectl rollout undo`,
  which is exactly what Task C's automated rollback relies on.
- Requires discipline to actually run the contract step later, rather
  than leaving dead columns around indefinitely — tracked as a follow-up
  in `docs/RCA.md` action items.

---

## ADR-003: Staging/prod cost split, not staging feature parity

**Context**
Staging must be deployable under $250/month (Task D). Full prod-parity
(Multi-AZ RDS, per-AZ NAT, larger node types) would blow well past that.

**Options considered**
1. Identical staging/prod topology, accept the higher staging cost.
2. **Same Terraform modules, different input variables per
   environment** — asymmetric resource sizing and redundancy, sharing
   100% of the module code.

**Decision:** option 2. See `infra/terraform/environments/staging/cost-estimate.md`
for the full breakdown and specific trade-offs (single NAT gateway,
single-AZ RDS, smaller instance classes).

**Consequences**
- Staging cannot be used to validate AZ-failover behaviour — that has
  to be tested in prod (with care) or a dedicated DR drill environment,
  noted in `docs/NOT-DONE.md`.
- Any config drift between environments is a variable-value diff, not a
  module-code diff, keeping the two environments genuinely comparable
  everywhere that matters (app config, security groups, IAM shape).
