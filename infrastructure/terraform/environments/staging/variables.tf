variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "backend_image" {
  type        = string
  description = "Docker image URI for the backend service"
}
