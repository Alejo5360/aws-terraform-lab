terraform {
  # Even without a local override, state stays in the checkout's parent directory.
  # prepare-bootstrap.ps1 overrides these with absolute paths in a private location.
  backend "local" {
    path          = "../../../.local-state/aws-terraform-lab/bootstrap/terraform.tfstate"
    workspace_dir = "../../../.local-state/aws-terraform-lab/bootstrap/workspaces"
  }
}
