# Disposable dev workload scaffold

This root will manage the VPC, IAM service access, and temporary EC2 workload from [the architecture baseline](../../../docs/architecture.md). It currently contains no resources or data sources.

The partial S3 backend is intentionally unconfigured. A normal initialization or plan requires the real backend from the future bootstrap milestone. For local checks only, use `init -backend=false` and `validate` as documented in [the local-development guide](../../../docs/local-development.md).

Do not add example bucket names or credentials to the backend block. Supply non-secret backend settings through an ignored local configuration only after the backend exists. No plan, apply, destroy, or AWS resource verification is part of the preparation milestone.

Before implementation, confirm the VPC CIDR, operator's current source /32, live Free plan and credit coverage, AMI, permissions, and quotas. The scaffold alone does not enforce the cost operating limits.
