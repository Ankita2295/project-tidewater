# Staging monthly cost estimate (us-east-1, on-demand)

| Resource                              | Est. $/mo |
|----------------------------------------|----------:|
| EKS control plane                      |     73.00 |
| EC2 t3.medium x2 (nodes)               |     60.00 |
| NAT Gateway x1 (single, not per-AZ)    |     32.40 |
| NAT data processing (~50GB)            |      2.25 |
| RDS db.t4g.micro, single-AZ, 20GB gp3  |     14.00 |
| ElastiCache cache.t4g.micro, 1 node    |     11.50 |
| Secrets Manager (2 secrets)            |      0.80 |
| S3 + DynamoDB (tfstate)                |      0.50 |
| **Total**                              | **~194.45** |

Headroom to the $250/mo ceiling: ~$55, kept deliberately for data
transfer variance and CloudWatch log ingestion, which are usage-based
and hard to pin exactly in advance.

## Trade-offs made to hit budget
- **Single NAT gateway** instead of one per AZ (saves ~$32/mo + halves
  data processing charges). Accepted risk: an AZ failure taking down the
  NAT briefly affects egress from the other AZ's private subnets. Not
  acceptable for prod — `environments/prod` uses one NAT per AZ.
- **Single-AZ RDS** instead of Multi-AZ (saves ~$14/mo, roughly doubles
  in absolute terms at this instance size, but small either way — the
  real saving is avoiding the failover replica's IOPS/storage cost at
  larger instance classes). Accepted risk: no automatic failover in
  staging; acceptable since staging isn't customer-facing.
- **cache.t4g.micro single-node Redis**, no replica. Accepted risk: a
  Redis restart briefly drops in-flight queue state in staging only.
- **t3.medium nodes** rather than larger instance types, sized to the
  HPA's own ceiling (max 6 API replicas, see deploy/k8s/hpa.yaml) so
  we're not paying for headroom staging will never use.

Prod removes every one of these trade-offs (see `environments/prod/main.tf`
and ADR-003 in `docs/DECISIONS.md`); this budget applies to staging only.
