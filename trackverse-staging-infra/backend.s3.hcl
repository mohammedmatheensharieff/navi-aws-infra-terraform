# Remote backend (S3 + DynamoDB for team use)
bucket         = "trackverse-terraform-backend"     # <-- change
key            = "staging/infra/terraform.tfstate"  # <-- customize path
region         = "ap-south-1"
dynamodb_table = "terraform-locks"                  # <-- must exist
encrypt        = true
