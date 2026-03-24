variable "project_name" {
  type    = string
  default = "inventario"
}

variable "environment" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "backend_image" {
  type = string
}

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 2
}

variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 10
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "backend_security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "database_url_secret_arn" {
  type = string
}

variable "redis_url_secret_arn" {
  type = string
}

variable "jwt_secret_arn" {
  type = string
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
