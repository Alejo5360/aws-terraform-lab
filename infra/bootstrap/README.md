# Protected state bootstrap

This root manages the S3 state bucket in `us-east-2`. **Its authorized creation and live verification are complete.** The `dev` workload remains a separate scaffold.

The [creation record](../../docs/bootstrap-deployment.md) confirms six resources added and verified bucket protections. The separately authorized [migration record](../../docs/bootstrap-state-migration.md) confirms authoritative S3 state and a no-change plan from an independently initialized client. Local snapshots are protected recovery artifacts only; do not apply the used creation plan again.

The configuration enables versioning, SSE-S3 encryption, blocked public access, disabled ACLs, a transport-security policy, and bucket deletion guards. Backend outputs define separate `bootstrap` and `dev` keys with S3 native locking. No DynamoDB table or custom KMS key is needed.

The active backend is S3 with settings supplied through the verified external `bootstrap.s3.tfbackend.json`. Keep `TF_DATA_DIR` external too. Use [the fresh-checkout procedure](../../docs/bootstrap.md#connect-a-fresh-checkout-after-migration) to reconnect; never initialize empty local state to manage the existing bucket.

The [preparation helper](../../scripts/prepare-bootstrap.ps1) and `backend.local.tf.example` remain available for initial provisioning or separately authorized recovery. They do not select or reconnect the active S3 backend. Review local filesystem access before using recovery paths.

Follow [the bootstrap runbook](../../docs/bootstrap.md) for the future cost preflight, provisioning review, migration, recovery, and separate final cleanup. Those operations need their own authorization. For checks that require no AWS login, see [local development](../../docs/local-development.md).
