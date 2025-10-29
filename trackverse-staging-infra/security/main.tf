locals {
  name  = var.project
  ports = [for p in split(",", var.ingest_ports) : trimspace(p)]
}

# --- Pull outputs from network stack ---
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.network_state_bucket
    key     = var.network_state_key
    region  = var.network_state_region
    encrypt = true
  }
}

locals {
  vpc_id         = data.terraform_remote_state.network.outputs.vpc_id
  public_ids     = data.terraform_remote_state.network.outputs.public_subnet_ids
  app_subnet_ids = data.terraform_remote_state.network.outputs.private_app_subnet_ids
  db_subnet_ids  = data.terraform_remote_state.network.outputs.private_db_subnet_ids
}

############################
# 1) ALB SG
############################
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "ALB public access"
  vpc_id      = local.vpc_id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-alb-sg" }
}

############################
# 2) API + Web SG
############################
resource "aws_security_group" "api" {
  name        = "${local.name}-api-sg"
  description = "API and Web EC2 SG"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow API 3000 from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Allow Web 8080 from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-api-sg" }
}

############################
# 3) Ingestor SG
############################
data "aws_subnet" "public" {
  for_each = toset(local.public_ids)
  id       = each.value
}

resource "aws_security_group" "ingest" {
  name        = "${local.name}-ingest-sg"
  description = "GPS ingestion EC2 SG"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = local.ports
    content {
      description = "Allow TCP ${ingress.value} from NLB public subnets"
      from_port   = tonumber(ingress.value)
      to_port     = tonumber(ingress.value)
      protocol    = "tcp"
      cidr_blocks = [for s in values(data.aws_subnet.public) : s.cidr_block]
    }
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-ingest-sg" }
}

############################
# 4) RDS + Redis SG
############################
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS MySQL SG"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow MySQL 3306 from API and Ingest"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id, aws_security_group.ingest.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-rds-sg" }
}

resource "aws_security_group" "redis" {
  name        = "${local.name}-redis-sg"
  description = "Redis SG"
  vpc_id      = local.vpc_id

  ingress {
    description     = "Allow Redis 6379 from API and Ingest"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id, aws_security_group.ingest.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}-redis-sg" }
}

############################
# 5) SSM IAM Role + Instance Profile
############################
data "aws_iam_policy_document" "ssm_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_ssm_role" {
  name               = "${local.name}-ec2-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ssm_assume.json
  tags               = { Name = "${local.name}-ec2-ssm-role" }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${local.name}-ec2-ssm"
  role = aws_iam_role.ec2_ssm_role.name
}
