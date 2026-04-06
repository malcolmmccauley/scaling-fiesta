variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "github_org" {
  description = "GitHub organization or username that owns the repository"
  type        = string
  default     = "malcolmmccauley"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "scaling-fiesta"
}

variable "state_bucket" {
  description = "S3 bucket name for Terraform state storage"
  type        = string
  default     = "thebestbucketintheworld"
}

variable "state_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}
