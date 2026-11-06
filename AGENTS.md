# Working on AWS Terraform Lab

- Explain steps and decisions clearly; the user's preferred guidance level is HIGH.
- The AWS profile is devops-free and the only resource Region is us-east-2.
- Preserve the zero-out-of-pocket requirement. Never upgrade the AWS project to PAID, activate advanced features, buy commitments, or add paid features to make a step work.
- The current milestone authorizes repository preparation and local validation. Resource implementation, backend creation, and deployment are not part of this milestone. Do not run plan, apply, destroy, import, refresh, or state-changing commands without a later user instruction covering that work.
- Never place credentials, tokens, login caches, Terraform state, or saved plans in the checkout. Ignoring state in Git is not a substitute for keeping actual state outside the repository.
- Initialize scaffolds only with init -backend=false. Before implementing bootstrap resources, configure a protected state path outside this checkout; later migrate it to the remote backend. The dev root declares a partial S3 backend that is not yet configured.
- Keep bootstrap and dev as separate Terraform roots and state lifecycles. Workload cleanup must not delete the backend that tracks it.
- Keep Terraform and AWS provider versions pinned; commit .terraform.lock.hcl in both roots. Update pins and lock files together after review.
- Use fmt and validate for this milestone. Neither proves that IAM permissions, service quotas, credit coverage, or launch capacity are sufficient.
- Recheck the live FREE / ACTIVE plan, credits, expiry, and selected Region before any future deployment. The cost snapshot is a dated estimate, not a bill or a spending cap.
- Prefer the AWS MCP server for AWS service work. If unavailable, use the installed AWS CLI and relevant local skills; do not bypass access denials or inspect credential stores.
