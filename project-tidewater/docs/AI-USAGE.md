# AI Usage

I used Claude (Anthropic) to scaffold generic, non-incident-specific
infrastructure code from a description of the desired end state:
- Initial Dockerfile, k8s manifest, and Terraform module structure
- First draft of the GitHub Actions pipeline stages
- First draft of doc templates (RUNBOOK, DECISIONS, CHANGES, NOT-DONE)

What I corrected / had to redo by hand:
- [Fill in: any DB connection budget numbers, once verified against the
  actual `deploy/k8s/hpa.yaml` you run and the real Postgres config]
- [Fill in: RCA.md was written entirely by me from the real evidence
  bundle — no AI-generated content in that file, since it requires
  citing specific evidence]
- [Fill in: anything you changed in the generated Terraform/k8s/CI once
  you actually ran it against your cluster and it didn't work as generated]

I did not use AI to write `docs/RCA.md` — that required reading the
actual incident evidence bundle and forming my own causal hypothesis,
which I verified independently before writing it up.
