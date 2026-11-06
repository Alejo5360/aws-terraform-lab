provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "aws-terraform-lab"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}
