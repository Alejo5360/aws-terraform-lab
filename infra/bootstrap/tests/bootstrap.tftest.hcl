# All AWS operations are mocked. This is a documentation fixture, not a real project.
mock_provider "aws" {
  override_during = plan

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
}

variables {
  expected_account_id = "123456789012"
}

run "secure_state_bucket" {
  command = plan

  assert {
    condition     = aws_s3_bucket.state.bucket == "aws-terraform-lab-tfstate-123456789012-us-east-2" && !aws_s3_bucket.state.force_destroy
    error_message = "State must have a project-qualified name and must not allow forced emptying."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.state.block_public_acls &&
      aws_s3_bucket_public_access_block.state.block_public_policy &&
      aws_s3_bucket_public_access_block.state.ignore_public_acls &&
      aws_s3_bucket_public_access_block.state.restrict_public_buckets &&
      one(aws_s3_bucket_ownership_controls.state.rule).object_ownership == "BucketOwnerEnforced"
    )
    error_message = "All public access protections and bucket-owner-enforced ownership must remain enabled."
  }

  assert {
    condition = (
      one(aws_s3_bucket_versioning.state.versioning_configuration).status == "Enabled" &&
      one(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256" &&
      contains(one(aws_s3_bucket_server_side_encryption_configuration.state.rule).blocked_encryption_types, "SSE-C")
    )
    error_message = "State needs versioning, SSE-S3 encryption, and protection against SSE-C uploads."
  }

  assert {
    condition = (
      length(jsondecode(aws_s3_bucket_policy.state.policy).Statement) == 1 &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:SecureTransport"] == "false" &&
      jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Condition.Bool["aws:PrincipalIsAWSService"] == "false" &&
      toset(jsondecode(aws_s3_bucket_policy.state.policy).Statement[0].Resource) == toset([
        "arn:aws:s3:::aws-terraform-lab-tfstate-123456789012-us-east-2",
        "arn:aws:s3:::aws-terraform-lab-tfstate-123456789012-us-east-2/*"
      ])
    )
    error_message = "The transport policy must deny insecure client requests, scope only this bucket and its objects, and avoid granting public access."
  }
}

run "separate_backend_contracts" {
  command = plan

  assert {
    condition = (
      output.backend_configs.bootstrap.key == "bootstrap/terraform.tfstate" &&
      output.backend_configs.dev.key == "dev/terraform.tfstate" &&
      output.backend_configs.bootstrap.bucket == output.backend_configs.dev.bucket &&
      alltrue([for config in values(output.backend_configs) : (
        config.region == "us-east-2" && config.encrypt && config.use_lockfile &&
        config.allowed_account_ids == ["123456789012"] && config.profile == "devops-free"
      )])
    )
    error_message = "Bootstrap and dev must use separate state keys with native locking, encryption, and the project guard."
  }
}

run "reject_other_region" {
  command = plan
  variables {
    aws_region = "us-west-2"
  }
  expect_failures = [var.aws_region]
}

run "reject_malformed_project" {
  command = plan
  variables {
    expected_account_id = "invalid"
  }
  expect_failures = [var.expected_account_id]
}

run "reject_other_project" {
  command = plan
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "999999999999"
    }
  }
  expect_failures = [aws_s3_bucket.state]
}

run "reject_empty_profile" {
  command = plan
  variables {
    aws_profile = " "
  }
  expect_failures = [var.aws_profile]
}
