# Bootstrap, state migration, and recovery

**Implementation date: 2026-11-09. Current status: S3 creation and state migration authorized, completed, and verified.** Commands below describe procedures, not an instruction to repeat completed operations. AWS changes require authorization for the corresponding milestone.

**Live update:** the [preflight and plan review](bootstrap-plan-review.md), authorized [creation](bootstrap-deployment.md), and authorized [migration](bootstrap-state-migration.md) passed. Authoritative state is now in S3 at `bootstrap/terraform.tfstate`. Protected local snapshots are recovery artifacts only. Do not apply the used creation plan again or reconnect the old local state as an independent writer.

## Ownership and protections

`infra/bootstrap` owns one durable S3 bucket and five configuration/policy resources. `infra/environments/dev` will own the disposable workload. A routine workload teardown must preserve the bucket and both state histories.

| Setting | Implementation and purpose |
| --- | --- |
| Project / Region | Required `expected_account_id`, provider `allowed_account_ids`, identity precondition, and `us-east-2` validation |
| Bucket name | `aws-terraform-lab-tfstate-<project-id>-us-east-2`; use the verified external output for this existing bucket |
| Public access | All four S3 Block Public Access settings enabled |
| Ownership | `BucketOwnerEnforced`; ACLs disabled |
| Encryption | SSE-S3 (`AES256`), with SSE-C uploads blocked; no custom KMS key |
| Transport | Bucket policy denies insecure non-service client requests; it grants no access |
| Recovery | S3 versioning enabled; no automatic state-version expiration |
| Accidental deletion | `prevent_destroy = true` and `force_destroy = false` |
| Concurrency | Backend output enables S3 native `use_lockfile`; no DynamoDB table |
| State separation | `bootstrap/terraform.tfstate` and `dev/terraform.tfstate`; bootstrap uses only the default workspace |

`prevent_destroy` is a Terraform configuration guard, not an AWS deletion-deny policy. Removing the resource configuration can remove that guard. `force_destroy = false` prevents Terraform from emptying a non-empty bucket automatically. Neither replaces backups or careful access control.

Initial provisioning uses a local backend; the migration switches the active declaration to S3. The recovery template `infra/bootstrap/backend.local.tf.example` has a fallback at `../../../.local-state/aws-terraform-lab/bootstrap/terraform.tfstate`, outside the checkout when resolved from the bootstrap root. The helper supplies absolute paths in a private user-profile directory instead. Never rely on Terraform's implicit in-repository state location or replace the active S3 backend casually.

## Connect a fresh checkout after migration

Use this procedure only after remote state has been verified authoritative. Obtain the verified external `bootstrap.s3.tfbackend.json` and `bootstrap.inputs.tfvars.json` from the operator's protected artifacts. Do not put either into Git or reconstruct the bucket name from the documentation fixture. Use a new external metadata directory so an unrelated initialized backend cannot be silently repointed.

```powershell
$stateDirectory = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/state/aws-terraform-lab/bootstrap'
$backendConfig = Join-Path $stateDirectory 'bootstrap.s3.tfbackend.json'
$inputsFile = Join-Path $stateDirectory 'bootstrap.inputs.tfvars.json'
$env:TF_DATA_DIR = Join-Path $stateDirectory 'terraform-data-new-checkout'
$env:TF_WORKSPACE = 'default'
if (Test-Path -LiteralPath (Join-Path $env:TF_DATA_DIR 'terraform.tfstate')) {
    throw 'Choose a new external metadata directory or inspect the existing backend first.'
}
$tf = 'terraform'
& $tf -chdir=infra/bootstrap init "-backend-config=$backendConfig" -input=false -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'S3 initialization failed; do not fall back to empty local state.' }
& $tf -chdir=infra/bootstrap state list
& $tf -chdir=infra/bootstrap plan "-var-file=$inputsFile" -input=false -detailed-exitcode
if ($LASTEXITCODE -ne 0) { throw 'Expected an unchanged bootstrap; inspect the result before any apply.' }
```

Verify all six expected managed addresses before planning. Never apply a plan proposing six new creations against the already existing bootstrap: that can mean the client selected an empty state or the wrong key. The helper `prepare-bootstrap.ps1` remains useful for initial local preparation and reviewed recovery; it does not initialize or select the remote backend.

## 1. Prepare external paths

Run from the repository root. Local validation uses [different commands](local-development.md#local-checks-for-this-milestone) and does not need AWS login.

Before any future provisioning, renew the existing temporary-credential session if needed and verify:

1. The intended project is still **FREE / ACTIVE**; do not upgrade it or enable advanced features.
2. Available credits/allowances cover expected S3 storage, retained versions, requests, and locking operations with a buffer. Check their expiry and all other project usage in **AWS Settings > Billing**. The dated cost estimate is not a current balance or spending cap.
3. The selected Region is `us-east-2`: **AWS Settings > View all projects > Overview > Additional Info > Region**. Compare it with the local profile configuration.
4. The user has explicitly authorized the live plan and subsequent deployment milestone. Stop if any condition is unverified.

Read-only preflight commands, for that future milestone:

```powershell
$aws = "aws"
& $aws configure get region --profile devops-free
& $aws freetier get-account-plan-state --profile devops-free --region us-east-2
if ($LASTEXITCODE -ne 0) { throw "Cannot verify the active AWS plan." }
$projectId = (& $aws sts get-caller-identity --profile devops-free --region us-east-2 --query Account --output text)
if ($LASTEXITCODE -ne 0) { throw "Cannot verify the signed-in project." }
$projectId = $projectId.Trim()
```

Compare the returned identity with the intended project; a successful login alone does not establish this. Do not put its actual ID or credentials into the tracked example. The example ID `123456789012` is a documentation/test fixture only.

Generate the local configuration using the verified ID:

```powershell
$paths = & ./scripts/prepare-bootstrap.ps1 -ExpectedAccountId $projectId
$env:TF_DATA_DIR = $paths.TerraformDataDir
$tf = "terraform" # Or the absolute path to the verified 1.17.1 executable.
```

The default directory is `<user-profile>/.local/state/aws-terraform-lab/bootstrap`. You may supply another absolute external directory with `-StateDirectory`. Review its OS permissions and disk protection; avoid shared or cloud-synchronized folders. The helper does not encrypt local files or change their permissions.

It writes only UTF-8 JSON backend configuration and input files. It returns paths for future state, metadata, and saved plans without creating those artifacts. It rejects checkout paths, linked ancestors, conflicting configuration, and invalid project IDs. Identical reruns preserve existing configuration. Keep the entire directory and any backups outside Git; never add access keys to the generated files.

Use a separate external `TF_DATA_DIR` for every Terraform root. Backend metadata can contain configuration details, and saved plans can contain sensitive values. Do not reuse bootstrap metadata for `dev`.

## 2. Future provisioning and review

**Do not execute this section until deployment is authorized and the fresh preflight passes.** Keep `backend.tf` configured as `local` for initial provisioning. Check `terraform workspace show` is `default` before the plan.

This is the initial-creation procedure, not the normal connection procedure for the existing bucket. When starting a separately approved new bootstrap, replace the active declaration with `backend.local.tf.example` before initialization. Do not do that to reconnect to the existing lab. After first enabling bucket versioning, [AWS recommends waiting 15 minutes before object writes](https://docs.aws.amazon.com/AmazonS3/latest/userguide/manage-versioning-examples.html), including state migration and lock-file operations.

```powershell
& $tf -chdir=infra/bootstrap init -reconfigure "-backend-config=$($paths.BackendConfig)" -input=false -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw "Bootstrap initialization failed." }
& $tf -chdir=infra/bootstrap workspace show
& $tf -chdir=infra/bootstrap plan "-var-file=$($paths.VariablesFile)" "-out=$($paths.PlanFile)"
if ($LASTEXITCODE -ne 0) { throw "Bootstrap plan failed." }
```

Review the saved plan: one bucket plus its five security/configuration resources, the intended project/Region, no replacements or deletions, and no unrelated services. Verify the external state/plan paths. Do not bypass a name conflict or permission failure by changing projects, importing unknown resources, or relaxing protections.

After the reviewed plan is approved, and while its credentials and cost assumptions remain valid:

```powershell
& $tf -chdir=infra/bootstrap apply $paths.PlanFile
if ($LASTEXITCODE -ne 0) { throw "Bootstrap apply failed; inspect partial results before retrying." }
```

Applying a saved plan runs without an additional confirmation prompt; approval must happen before that command. Preserve initial state even after a partial failure; it may already track successfully created resources. Verify bucket settings and retention after success. Local/mock tests do not establish live permissions, service support, quotas, or global bucket-name availability.

## 3. Export distinct remote configurations

Only after a successful apply, obtain the non-secret settings from the actual outputs. Keep the generated files external; they identify the real project even though they contain no credentials.

```powershell
$rawConfigs = & $tf -chdir=infra/bootstrap output -json backend_configs
if ($LASTEXITCODE -ne 0) { throw "Cannot read backend outputs." }
$configs = $rawConfigs | ConvertFrom-Json
$bootstrapS3 = Join-Path $paths.StateDirectory 'bootstrap.s3.tfbackend.json'
$devS3 = Join-Path $paths.StateDirectory 'dev.s3.tfbackend.json'
$exports = [ordered]@{
    $bootstrapS3 = ($configs.bootstrap | ConvertTo-Json -Depth 10)
    $devS3 = ($configs.dev | ConvertTo-Json -Depth 10)
}
foreach ($entry in $exports.GetEnumerator()) {
    if (Test-Path -LiteralPath $entry.Key) { throw "Inspect existing backend export first: $($entry.Key)" }
}
foreach ($entry in $exports.GetEnumerator()) {
    [IO.File]::WriteAllText($entry.Key, $entry.Value, [Text.UTF8Encoding]::new($false))
}
```

Review the resulting bucket, keys, profile, Region, `allowed_account_ids`, encryption, and `use_lockfile`. S3 backend access needs bucket listing, object reads/writes for the selected state key, and reads/writes/deletion for its `.tflock` object. Do not grant the EC2 instance access to Terraform state. Review narrower operator permissions before automation; this milestone creates no human-access roles or broad permission grants.

## 4. Migrate bootstrap state to S3

Treat migration as its own authorized state change. Pause all Terraform writers. Back up the local state, any backup file, the local backend configuration, and the source `backend.tf` to the protected external directory. Give backups unique names and retain the original files until verification is complete.

1. Keep the same external `TF_DATA_DIR` used for local provisioning so Terraform knows the previous backend.
2. Replace the tracked `infra/bootstrap/backend.tf` with the contents of `backend.s3.tf.example`. Only one backend block may be active.
3. Run the interactive migration and inspect its prompts:

```powershell
Copy-Item -LiteralPath infra/bootstrap/backend.s3.tf.example -Destination infra/bootstrap/backend.tf
& $tf -chdir=infra/bootstrap init -migrate-state "-backend-config=$bootstrapS3" -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw "Stop and determine which backend is authoritative before retrying." }
& $tf -chdir=infra/bootstrap state list
& $tf -chdir=infra/bootstrap output state_bucket_name
```

Do not combine `-migrate-state` with `-reconfigure`, use `-force-copy`, or accept an unexplained overwrite. Verify all six managed resource addresses, bucket output, and the remote state's lineage/serial against the protected local backup. Validate remote readability with a fresh external metadata directory initialized to the same S3 configuration; do not run concurrent writes. A subsequent authorized review plan should show no changes.

Compare the full resource data and outputs as well as metadata. Investigate a changed lineage or serial before declaring success; do not edit them to make a comparison pass. In this lab's verified Terraform 1.17.1 migration to an absent default-workspace object, the payload was preserved but remote metadata began a new lineage at serial 1. The [migration record](bootstrap-state-migration.md#metadata-transition) explains the pinned source path and evidence. Serials from different lineages do not form a shared sequence.

Commit only the reviewed backend source switch, for example `chore(bootstrap): migrate bootstrap state to S3`. Never commit state, generated backend files, or metadata. Retain a protected recovery copy of the original local state under the agreed retention policy.

For future `dev` initialization, use its own external metadata directory and `$devS3`. Its partial S3 backend is already declared, with the distinct `dev/terraform.tfstate` key. This does not authorize implementation or deployment of the workload.

## 5. Recovery

**Failed migration:** stop writers and preserve both copies. Inspect local and remote state lineage, serial, resource addresses, and the migration output. A failed command can still have copied state successfully. Do not blindly switch back to the local backend or retry over an existing remote state. Establish which copy is authoritative before a reviewed recovery. Never use `state push -force` to suppress unexplained conflicts.

**Stale lock:** first establish that no Terraform process still owns the operation. Identify its owner and operation details. Only an explicitly authorized stale-lock recovery may unlock it; never force-unlock an active writer or delete `.tflock` as routine cleanup.

**Recover an earlier S3 state version:**

1. Pause every Terraform writer, including other computers and future automation. Resolve active operations first; restoration through S3 bypasses Terraform's locking and serial checks.
2. Save the current state with `terraform state pull` to a uniquely named external file using UTF-8 without BOM. Check the command exit status before writing. Preserve current S3 version IDs and metadata too.
3. Use S3 `list-object-versions` for the exact bucket and state key. Download candidate versions with `get-object --version-id` to external files. Use `--expected-bucket-owner` with the verified project ID on S3 API operations that support it. Review lineage, serial, resource history, and any infrastructure changes since the candidate version.
4. After explicit recovery approval, restore the selected version to the same key using an S3 version-copy operation. URL-encode the source VersionId in `CopySource`. Copying creates a new current version and preserves the prior history; do not delete other versions or change the state key as a shortcut.
5. Verify the resulting state and bucket protections, then run an authorized review plan to identify drift. Restoring state does not undo AWS resource changes. Investigate differences before any apply and resume writers only after verification.

Do not treat a state file as a credential-free document: it may contain sensitive outputs and identifiers. Recovery copies need the same protection as current state.

## 6. Final backend cleanup

The state bucket outlives normal practice sessions and continues to consume storage/request allowances. Keep it only while needed, and recheck credit coverage during its lifetime.

Final removal needs separate approval. First remove the workload through its reviewed teardown and verify no managed workload remains. Inventory both state histories and any consumers. Migrate bootstrap state back to a protected local backend before removing the bucket; verify the local copy is authoritative and preserve the required recovery records externally.

For that separately authorized reverse migration, pause all writers and first export a protected current-state snapshot. Use a **new, empty external local-state directory** so an old pre-migration file cannot silently become authoritative. Keep the current S3-initialized `TF_DATA_DIR`; the new helper result must not replace it during migration.

```powershell
# Procedure only: requires separate recovery/cleanup authorization.
# $stateDirectory, $inputsFile, $tf, and the S3-initialized TF_DATA_DIR come
# from the verified current setup, not from an unrelated checkout.
$snapshot = & $tf -chdir=infra/bootstrap state pull
if ($LASTEXITCODE -ne 0) { throw 'Cannot back up authoritative remote state.' }
$stamp = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')
$snapshotFile = Join-Path $stateDirectory "before-reverse-migration-$stamp.tfstate"
if (Test-Path -LiteralPath $snapshotFile) { throw 'Backup destination already exists.' }
[IO.File]::WriteAllText($snapshotFile, ($snapshot -join "`n"), [Text.UTF8Encoding]::new($false))
$projectId = (Get-Content -LiteralPath $inputsFile -Raw | ConvertFrom-Json).expected_account_id
$recoveryDirectory = Join-Path $stateDirectory "local-recovery-$stamp"
if (Test-Path -LiteralPath $recoveryDirectory) { throw 'Recovery directory must be new.' }
$recovery = & ./scripts/prepare-bootstrap.ps1 -ExpectedAccountId $projectId -StateDirectory $recoveryDirectory
# Preserve a separate source copy before this replacement as well.
Copy-Item -LiteralPath infra/bootstrap/backend.local.tf.example -Destination infra/bootstrap/backend.tf
& $tf -chdir=infra/bootstrap init -migrate-state "-backend-config=$($recovery.BackendConfig)" -lockfile=readonly
if ($LASTEXITCODE -ne 0) { throw 'Stop and establish state authority before retrying.' }
& $tf -chdir=infra/bootstrap state list
```

Inspect the prompt and compare the resulting local state's lineage, serial, resource addresses, and IDs with the saved remote snapshot before treating it as authoritative. Keep all remote versions and external backups until the reviewed cleanup explicitly authorizes their deletion. Do not use `-reconfigure` or `-force-copy` as a shortcut, and do not immediately destroy resources after an unverified migration.

Only then review a deliberate change to `prevent_destroy` and a bootstrap destruction plan. Keep `force_destroy = false`. Inspect and approve the exact object versions and delete markers to purge; deleting them is irreversible. Never use an automatic recursive empty-bucket operation or expire state versions as a normal workload cleanup. Verify the bucket is gone and account for every retained local backup afterward.

## Evidence and references

On 2026-11-09, Windows AMD64 checks passed: Terraform formatting and validation, six native tests with a fully mocked AWS provider, eight external-path/helper tests, and a local-backend initialization using the generated JSON. Backend metadata stayed external; no resource state, saved plan, AWS API call, or AWS resource change was needed. Linux lock hashes are present; Linux execution and live locking/recovery drills remain unverified.

The separately authorized live milestones are recorded in [creation evidence](bootstrap-deployment.md) and [migration evidence](bootstrap-state-migration.md). After switching the backend declaration, validation and all six mocked tests passed again. Independent remote initialization, complete state-payload comparison, encrypted/versioned object checks, native lock activity/release, and a no-change live plan passed. A deliberate concurrent-writer drill and recovery drill remain unperformed.

- [Terraform local backend](https://developer.hashicorp.com/terraform/language/backend/local)
- [Terraform S3 backend, permissions, native locking, and configuration](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform provider mocking](https://developer.hashicorp.com/terraform/language/tests/mocking)
- [S3 security best practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 policy condition keys and AWS service-principal exceptions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html)
- [Restoring S3 object versions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/RestoringPreviousVersions.html)
