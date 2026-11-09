# Working on AWS Terraform Lab

- Explain steps and decisions clearly; the user's preferred guidance level is HIGH.
- The AWS profile is devops-free and the only resource Region is us-east-2.
- Preserve the zero-out-of-pocket requirement. Never upgrade the AWS project to PAID, activate advanced features, buy commitments, or add paid features to make a step work.
- The current milestone authorizes bootstrap resource code, external-state preparation, local checks, mocked tests, read-only AWS preflight, and the reviewed live bootstrap plan. AWS resource creation, backend migration, apply, destroy, import, refresh, and state-changing operations against AWS still need separate authorization.
- On 2026-11-09 the user explicitly authorized applying the reviewed S3 creation plan. That apply is complete: six resources created and live protections verified, with a subsequent no-change plan. The authorization was for that creation only; state migration, additional applies, and deletion remain separate decisions. Current authoritative bootstrap state is still in the protected external local backend.
- Never place credentials, tokens, login caches, Terraform state, or saved plans in the checkout. Ignoring state in Git is not a substitute for keeping actual state outside the repository.
- Use init -backend=false for normal local validation. Bootstrap live planning uses its explicit local backend and a private external TF_DATA_DIR, input file, and saved plan. prepare-bootstrap.ps1 generates absolute external paths; never create real state or saved plans inside the checkout. The dev S3 backend is still not configured.
- Keep bootstrap and dev as separate Terraform roots and state lifecycles. Workload cleanup must not delete the backend that tracks it.
- Keep Terraform and AWS provider versions pinned; commit .terraform.lock.hcl in both roots. Update pins and lock files together after review.
- Use fmt, validate, mocked Terraform tests, and helper tests for this milestone. They do not prove live IAM permissions, service quotas, credit coverage, or launch capacity.
- Recheck the live FREE / ACTIVE plan, credits, expiry, and selected Region before any future deployment. The cost snapshot is a dated estimate, not a bill or a spending cap.
- Prefer the AWS MCP server for AWS service work. If unavailable, use the installed AWS CLI and relevant local skills; do not bypass access denials or inspect credential stores.
