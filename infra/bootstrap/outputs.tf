output "state_bucket_name" {
  description = "Name of the state bucket, qualified by the signed-in project and Region."
  value       = local.state_bucket_name
}

output "backend_configs" {
  description = "Non-secret backend settings. Save each object as a .tfbackend.json outside the checkout after provisioning."
  value = {
    bootstrap = merge(local.backend_common, { key = "bootstrap/terraform.tfstate" })
    dev       = merge(local.backend_common, { key = "dev/terraform.tfstate" })
  }
}
