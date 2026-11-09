# Working on AWS Terraform Lab

- Explain steps and decisions clearly; the user's preferred guidance level is HIGH.
- The AWS profile is devops-free and the only resource Region is us-east-2.
- Preserve the zero-out-of-pocket requirement. Never upgrade the AWS project to PAID, activate advanced features, buy commitments, or add paid features to make a step work.
- Routine work authorizes local checks, mocked tests, and read-only bootstrap preflight/plans. The separately approved bootstrap creation and local-to-S3 migration are complete. Additional applies, AWS resource creation, destroy, import, state-changing refresh, further migrations, and deletion still need separate authorization.
- On 2026-11-09 the user explicitly authorized the reviewed S3 creation, then chose to retain the bucket and authorized migration to bootstrap/terraform.tfstate. S3 is now authoritative. All six managed resources and outputs match the protected local backup, and an independently initialized client returned a no-change plan. Native lock-file activity and subsequent release were verified; contention testing is not yet done.
- Terraform 1.17.1 generated a new remote lineage and serial 1 from local serial 7 while preserving the complete resource/output payload. The pinned source path was inspected and the transition documented. Old local state and snapshots are recovery artifacts only; never use them as a parallel writer or force-push them over the new remote lineage.
- Never place credentials, tokens, login caches, Terraform state, or saved plans in the checkout. Ignoring state in Git is not a substitute for keeping actual state outside the repository.
- Use init -backend=false with isolated external metadata per root for local validation; do not repurpose the active S3 metadata directory. Bootstrap live work uses its S3 backend with verified external configuration and a private external TF_DATA_DIR. prepare-bootstrap.ps1 only prepares initial local/recovery paths; it does not reconnect S3. The dev S3 backend is still not configured.
- Keep bootstrap and dev as separate Terraform roots and state lifecycles. Workload cleanup must not delete the backend that tracks it.
- Keep Terraform and AWS provider versions pinned; commit .terraform.lock.hcl in both roots. Update pins and lock files together after review.
- Use fmt, validate, mocked Terraform tests, and helper tests for this milestone. They do not prove live IAM permissions, service quotas, credit coverage, or launch capacity.
- Recheck the live FREE / ACTIVE plan, credits, expiry, and selected Region before any future deployment. The cost snapshot is a dated estimate, not a bill or a spending cap.
- Prefer the AWS MCP server for AWS service work. If unavailable, use the installed AWS CLI and relevant local skills; do not bypass access denials or inspect credential stores.
