# Protected state bootstrap

This root manages the S3 state bucket in `us-east-2`. **Its authorized creation and live verification are complete.** The `dev` workload remains a separate scaffold.

The [2026-11-09 creation record](../../docs/bootstrap-deployment.md) confirms six resources added, verified bucket protections, and a subsequent no-change plan. Bootstrap state is still in the protected external local backend, with an external backup. Remote-state migration remains pending authorization; do not apply the used creation plan again.

The configuration enables versioning, SSE-S3 encryption, blocked public access, disabled ACLs, a transport-security policy, and bucket deletion guards. Backend outputs define separate `bootstrap` and `dev` keys with S3 native locking. No DynamoDB table or custom KMS key is needed.

Initial state uses an explicit local backend outside the checkout. Prefer [the preparation helper](../../scripts/prepare-bootstrap.ps1), which generates absolute external paths and required project inputs without contacting AWS or creating state. The checked-in relative fallback also points outside the checkout; review filesystem access before using it.

Follow [the bootstrap runbook](../../docs/bootstrap.md) for the future cost preflight, provisioning review, migration, recovery, and separate final cleanup. Those operations need their own authorization. For checks that require no AWS login, see [local development](../../docs/local-development.md).
