data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "aws-terraform-lab-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  state_bucket_arn  = "arn:aws:s3:::${local.state_bucket_name}"

  backend_common = {
    bucket              = local.state_bucket_name
    region              = var.aws_region
    profile             = var.aws_profile
    encrypt             = true
    use_lockfile        = true
    allowed_account_ids = [var.expected_account_id]
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true

    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.expected_account_id
      error_message = "The signed-in AWS project does not match expected_account_id."
    }

    precondition {
      condition     = terraform.workspace == "default"
      error_message = "Bootstrap must use the default Terraform workspace."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    blocked_encryption_types = ["SSE-C"]

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [local.state_bucket_arn, "${local.state_bucket_arn}/*"]
      Condition = {
        Bool = {
          "aws:SecureTransport"       = "false"
          "aws:PrincipalIsAWSService" = "false"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.state]
}
