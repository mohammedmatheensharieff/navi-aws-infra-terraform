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

# Remote state from Step 2 (network)
variable "network_state_bucket" {
  description = "S3 bucket holding network state"
  type        = string
}

variable "network_state_key" {
  description = "Key/path to network state file in S3"
  type        = string
  default     = "staging/network.tfstate"
}

variable "network_state_region" {
  description = "Region of S3 bucket"
  type        = string
  default     = "ap-south-1"
}

# GPS TCP ports
variable "ingest_ports" {
  description = "Comma-separated GPS ingestion TCP ports"
  type        = string
  default     = "5000,5001,5002"
}
