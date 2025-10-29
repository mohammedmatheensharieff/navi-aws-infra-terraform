variable "project" {
  description = "Project name prefix for tagging all resources"
  type        = string
  default     = "trackverse-staging"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}
