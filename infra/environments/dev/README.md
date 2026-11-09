# Disposable dev workload scaffold

This root will manage the VPC, IAM service access, and temporary EC2 workload from [the architecture baseline](../../../docs/architecture.md). It currently contains no resources or data sources.

The partial S3 backend is intentionally unconfigured. The [bootstrap bucket is created and verified](../../../docs/bootstrap-deployment.md), but this root has not been initialized against it. For local checks only, use `init -backend=false` and `validate` as documented in [the local-development guide](../../../docs/local-development.md).

Do not add actual bucket names or credentials to the backend block. Use the external `dev.s3.tfbackend.json` exported from verified bootstrap outputs when that future milestone is authorized. Dev initialization, live planning, deployment, and cleanup remain separate from the completed bootstrap creation.

Before implementation, confirm the VPC CIDR, operator's current source /32, live Free plan and credit coverage, AMI, permissions, and quotas. The scaffold alone does not enforce the cost operating limits.
