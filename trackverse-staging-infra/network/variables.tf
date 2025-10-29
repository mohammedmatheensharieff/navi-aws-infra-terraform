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

variable "azs" {
  description = "AZs to spread subnets across"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

# Keep single NAT for staging (cheapest). Set true for 1-per-AZ in prod.
variable "nat_per_az" {
  description = "Create one NAT per AZ (true) or a single shared NAT (false)"
  type        = bool
  default     = false
}
