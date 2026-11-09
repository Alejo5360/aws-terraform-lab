provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project     = "aws-terraform-lab"
      Environment = "bootstrap"
      ManagedBy   = "Terraform"
    }
  }
}
