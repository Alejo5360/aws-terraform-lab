# Verified bootstrap state migration to S3

**Date:** 2026-11-09. **Final verification:** 09:23, America/Bogota. **Result:** authoritative bootstrap state is in S3 at `bootstrap/terraform.tfstate`; workload implementation remains pending.

## Authorization and safeguards

The user chose to retain the existing backend and explicitly authorized copying the protected local state to S3 and changing Terraform to use it. This milestone created no new infrastructure resources and ran no resource apply, destroy, forced state push, or manual unlock.

Preflight verified the intended `devops-free` identity, `us-east-2`, **FREE / ACTIVE**, sufficient credits above the planning buffer, and future expiry. The target state/lock keys had no object-version history. Versioning, SSE-S3, all public-access blocks, disabled ACLs, a non-public policy, and the transport-security deny were confirmed before upload.

State, source backend declaration, backend metadata, external settings, and inputs were backed up outside the checkout and checked by SHA-256. No other local Terraform process was running. The operation waited at least 15 minutes after the completed creation/state write before the first object write, following [AWS's versioning propagation recommendation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html).

## Migration performed

The active source declaration changed from `local` to partial `s3`. Actual bucket/project settings remain in the external `bootstrap.s3.tfbackend.json`; no credentials or real project identifiers were embedded in source.

The existing external `TF_DATA_DIR` retained knowledge of the local source. Terraform 1.17.1 ran `init -migrate-state` with the pinned provider lock file read-only. Its prompt identified the existing local source and an empty S3 destination. The authorized copy was confirmed only after inspecting that prompt. Neither `-force-copy` nor `-reconfigure` was used for migration.

## Evidence

| Check | Verified result |
| --- | --- |
| Active backend metadata | S3, correct key/Region/profile/project guard, encryption and `use_lockfile = true` |
| Managed resources | All six S3 resources preserved |
| Caller-identity data | Preserved |
| Complete resource records and outputs | Equal to the pre-migration local backup |
| Remote object | `AES256`, non-null VersionId, current version confirmed |
| Downloaded version | Resource/output payload equal to the local backup and metadata equal to the active remote state |
| Fresh external metadata directory | Independently initialized against the same S3 key and read all expected addresses |
| Live plan from independent initialization | Exit code 0; no changes |
| State after that plan | Same remote lineage, serial, and VersionId |
| Native locking | Lock-file object history observed; no active lock left afterward |
| Repository hygiene | No actual state, saved plan, generated backend configuration, or credentials in the checkout |

Formatting, configuration validation, and all six AWS-mocked Terraform tests also passed with isolated local metadata and the backend disabled. No dependency pin or provider lock changed.

## Metadata transition

The initial comparison found that the local snapshot had serial **7**, while the remote snapshot had a **new lineage and serial 1**. Verification stopped before further writes to investigate this difference. All resource records and outputs were already equal.

Inspection of the pinned [migration routine](https://github.com/hashicorp/terraform/blob/v1.17.1/internal/command/meta_backend_migrate.go) and [remote state persistence](https://github.com/hashicorp/terraform/blob/v1.17.1/internal/states/remote/state.go) explains the observed empty-destination path: persistence refreshes an absent remote snapshot and initializes new metadata. The [state-manager migration contract](https://github.com/hashicorp/terraform/blob/v1.17.1/internal/states/statemgr/migrate.go) preserves serial/lineage where possible and treats different lineages as unrelated sequences.

No metadata was manually edited or force-pushed. The actual S3 version was downloaded, its complete payload compared with the backup, and the new remote metadata confirmed stable from a fresh client and after a no-change plan. S3 is authoritative; the pre-migration local lineage is a historical recovery artifact. Do not compare serial 7 and serial 1 as if they belonged to one sequence, or overwrite the remote state with the old local file to make metadata match.

## Artifact handling and reconnecting

Protected artifacts remain under `<user-profile>/.local/state/aws-terraform-lab/bootstrap`: pre-migration backups, a downloaded remote version, private receipts with hashes/version IDs, backend settings, inputs, and external Terraform metadata. An external `STATE_AUTHORITY.md` records which backend to use. Old local state files are backups only and must not become a parallel writer.

Follow [the fresh-checkout procedure](bootstrap.md#connect-a-fresh-checkout-after-migration) to reconnect using the verified external S3 settings. Initial local and reverse-migration procedures are documented separately. Never silently select empty local state when remote access fails.

The `dev` backend still uses a separate planned key, `dev/terraform.tfstate`, and has not been initialized. No live contention drill, version-recovery drill, workload deployment, or final cleanup was performed. Those remain separate milestones.

## Cost and retention

The user chose to keep the bucket for the lab. State versions, lock-file versions/delete markers, storage, and requests consume applicable allowances or credits; [the reviewed operating envelope](bootstrap-plan-review.md#metered-usage-estimate) still applies. Recheck live credits and expiry during continued use. No paid-plan upgrade, custom KMS key, DynamoDB table, extra logging service, or advanced feature was enabled.

Keep protected snapshots while needed for recovery. A future version restore, reverse migration, or final deletion requires its own reviewed authorization under [the runbook](bootstrap.md).
