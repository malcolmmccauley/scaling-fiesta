variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "github_org" {
  description = "malcolmmccauley"
  type        = string
}

variable "github_repo" {
  description = "scaling-fiesta"
  type        = string
}

variable "state_bucket" {
  description = "thebestbucketintheworld"
  type        = string
}

variable "state_lock_table" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "terraform-state-lock"
}
