variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "private_subnet_cidrs" {
  description = "Private subnet ranges containing ECS tasks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "Private subnet ranges containing ECS tasks"
  type        = list(string)
}