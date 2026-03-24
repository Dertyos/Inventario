terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "inventario-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "inventario-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "inventario"
      Environment = "staging"
      ManagedBy   = "terraform"
    }
  }
}

locals {
  environment = "staging"
  tags = {
    Project     = "inventario"
    Environment = local.environment
  }
}

# --- Networking (VPC) ---
# Use default VPC for staging, dedicated VPC for production
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# --- Security Groups ---
resource "aws_security_group" "backend" {
  name_prefix = "inventario-backend-${local.environment}-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "alb" {
  name_prefix = "inventario-alb-${local.environment}-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

# --- ALB ---
resource "aws_lb" "main" {
  name               = "inventario-${local.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.default.ids

  tags = local.tags
}

resource "aws_lb_target_group" "backend" {
  name        = "inventario-backend-${local.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# --- IAM Roles ---
resource "aws_iam_role" "ecs_execution" {
  name = "inventario-ecs-execution-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "inventario-ecs-task-${local.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# --- Secrets Manager ---
resource "aws_secretsmanager_secret" "database_url" {
  name = "inventario/${local.environment}/database-url"
  tags = local.tags
}

resource "aws_secretsmanager_secret" "redis_url" {
  name = "inventario/${local.environment}/redis-url"
  tags = local.tags
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name = "inventario/${local.environment}/jwt-secret"
  tags = local.tags
}

# --- ECS Module ---
module "ecs" {
  source = "../../modules/ecs"

  project_name              = "inventario"
  environment               = local.environment
  aws_region                = var.aws_region
  backend_image             = var.backend_image
  backend_cpu               = 512
  backend_memory            = 1024
  desired_count             = 1
  min_capacity              = 1
  max_capacity              = 4
  execution_role_arn        = aws_iam_role.ecs_execution.arn
  task_role_arn             = aws_iam_role.ecs_task.arn
  private_subnet_ids        = data.aws_subnets.default.ids
  backend_security_group_id = aws_security_group.backend.id
  target_group_arn          = aws_lb_target_group.backend.arn
  database_url_secret_arn   = aws_secretsmanager_secret.database_url.arn
  redis_url_secret_arn      = aws_secretsmanager_secret.redis_url.arn
  jwt_secret_arn            = aws_secretsmanager_secret.jwt_secret.arn
  log_retention_days        = 14
  tags                      = local.tags
}
