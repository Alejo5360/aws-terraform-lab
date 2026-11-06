variable "aws_region" {
  description = "The selected AWS project Region. Regional resources must remain in Ohio."
  type        = string
  default     = "us-east-2"
  nullable    = false

  validation {
    condition     = var.aws_region == "us-east-2"
    error_message = "This AWS project supports resource deployment only in us-east-2."
  }
}

variable "aws_profile" {
  description = "Local AWS CLI profile providing temporary credentials; never supply access keys."
  type        = string
  default     = "devops-free"
  nullable    = false

  validation {
    condition     = length(trimspace(var.aws_profile)) > 0
    error_message = "Provide a non-empty AWS CLI profile name."
  }
}
